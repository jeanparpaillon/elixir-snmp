defmodule Snmp.Mib do
  @moduledoc """
  Helper for instrumentation module
  """
  require Record

  Record.defrecord(:mib, Record.extract(:mib, from_lib: "snmp/include/snmp_types.hrl"))
  Record.defrecord(:me, Record.extract(:me, from_lib: "snmp/include/snmp_types.hrl"))

  Record.defrecord(
    :asn1_type,
    Record.extract(:asn1_type, from_lib: "snmp/include/snmp_types.hrl")
  )

  Record.defrecord(
    :variable_info,
    Record.extract(:variable_info, from_lib: "snmp/include/snmp_types.hrl")
  )

  Record.defrecord(
    :table_info,
    Record.extract(:table_info, from_lib: "snmp/include/snmp_types.hrl")
  )

  @doc false
  defmacro __using__(path: src) when is_binary(src) do
    basename = Path.basename(src, ".mib")

    dest = Path.join([Mix.Project.app_path(), "priv", "mibs", basename <> ".bin"])
    :ok = File.mkdir_p!(Path.dirname(dest))
    opts = [{:module, __CALLER__.module}]
    {:ok, _dest} = compile_mib(src, dest, opts)
    {:ok, mib} = :snmpc_misc.read_mib('#{dest}')

    # IO.inspect(mib, label: "MIB")

    [
      quote do
        require Record

        @external_resource unquote(Macro.escape(src))
        @mibname unquote(basename)

        Module.register_attribute(__MODULE__, :varfun, accumulate: true)
        Module.register_attribute(__MODULE__, :tablefun, accumulate: true)
        Module.register_attribute(__MODULE__, :oid, accumulate: true)
        Module.register_attribute(__MODULE__, :range, accumulate: true)
        Module.register_attribute(__MODULE__, :default, accumulate: true)
        Module.register_attribute(__MODULE__, :enum, accumulate: true)

        @before_compile Snmp.Mib
      end
    ] ++
      Enum.map(mib(mib, :asn1_types), &parse_asn1_type/1) ++
      Enum.map(mib(mib, :mes), fn me ->
        IO.inspect(me, label: "ME")
        parse_me(me)
      end)
  end

  defmacro __before_compile__(env) do
    for enum <- Module.get_attribute(env.module, :enum) do
      gen_enum(enum, env)
    end ++
      for oid <- Module.get_attribute(env.module, :oid) do
        gen_oid(oid)
      end ++
      for oid <- Module.get_attribute(env.module, :oid) do
        gen_oname(oid)
      end ++
      [gen_oids(Module.get_attribute(env.module, :oid), env)] ++
      for range <- Module.get_attribute(env.module, :range) do
        gen_range(range)
      end
  end

  defp compile_mib(src, dest, opts) do
    project = Mix.Project.config()

    mib_includes =
      (Keyword.get(project, :mib_include_path, []) ++ [Path.dirname(dest) | project[:erlc_paths]])
      |> Enum.map(&'#{&1}')

    File.mkdir_p!(Path.dirname(dest))

    opts = [
      {:outdir, '#{Path.dirname(dest)}'},
      {:i, mib_includes},
      {:group_check, false},
      :no_defs | opts
    ]

    src = Path.expand(src)
    :snmpc.compile('#{src}', opts)
  end

  defp parse_asn1_type(asn1_type(imported: false, aliasname: name, assocList: [enums: enums])) do
    quote do
      @enum {unquote(name), unquote(enums)}
    end
  end

  defp parse_asn1_type(_), do: []

  defp parse_me(me(oid: oid, asn1_type: :undefined, aliasname: name)) do
    quote do
      @oid {unquote(oid), unquote(name)}
    end
  end

  defp parse_me(me(oid: oid, asn1_type: type, aliasname: name)) do
    asn1_type(bertype: bertype, lo: lo, hi: hi) = type

    ast = [
      quote do
        @oid {unquote(oid), unquote(name)}
      end
    ]

    ast =
      cond do
        :undefined == lo or :undefined == hi ->
          ast

        bertype in [:OCTET_STRING, :Unsigned32, :Counter32, :INTEGER] ->
          ast ++
            [
              quote do
                @range {unquote(name), unquote(lo), unquote(hi)}
              end
            ]

        true ->
          ast
      end

    ast =
      case type do
        asn1_type(imported: false, assocList: [enums: enums]) ->
          ast ++
            [
              quote do
                @enum {unquote(name), unquote(enums)}
              end
            ]

        _ ->
          ast
      end

    ast
  end

  defp gen_enum({name, values}, env) do
    quote do
      defmodule unquote(Module.concat(env.module, name)) do
        @moduledoc false
        use Snmp.Mib.TextualConvention, mapping: unquote(values)
      end
    end
  end

  defp gen_oid({oid, name}) do
    quote do
      def __oid__(unquote(name)), do: unquote(oid)
    end
  end

  defp gen_oname({oid, name}) do
    quote do
      def __oname__(unquote(oid)), do: unquote(name)
    end
  end

  defp gen_oids(oids, env) do
    mapping =
      oids
      |> Macro.expand(env)
      |> Enum.reduce(%{}, fn {oid, name}, acc -> Map.put(acc, name, oid) end)
      |> Macro.escape()

    quote do
      def __oids__, do: unquote(mapping)
    end
  end

  defp gen_range({_name, :undefined, :undefined}), do: []

  defp gen_range({name, lo, hi}) do
    quote do
      def __range__(unquote(name)), do: {unquote(lo), unquote(hi)}
    end
  end
end
