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

    IO.inspect(mib, label: "MIB")

    [
      quote do
        require Record

        @external_resource unquote(Macro.escape(src))
        @mibname unquote(basename)

        Module.register_attribute(__MODULE__, :varfuns, accumulate: true)
        Module.register_attribute(__MODULE__, :tablefuns, accumulate: true)
        Module.register_attribute(__MODULE__, :oids, accumulate: true)
        Module.register_attribute(__MODULE__, :range, accumulate: true)
        Module.register_attribute(__MODULE__, :default, accumulate: true)
        Module.register_attribute(__MODULE__, :enums, accumulate: true)

        @before_compile Snmp.Mib
      end
    ] ++ Enum.map(mib(mib, :asn1_types), &parse_asn1_type/1)
  end

  defmacro __before_compile__(env) do
    for enum <- Module.get_attribute(env.module, :enums) do
      gen_enum(enum, env)
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
      @enums {unquote(name), unquote(enums)}
    end
  end

  defp parse_asn1_type(_), do: []

  defp gen_enum({name, values}, env) do
    quote do
      defmodule unquote(Module.concat(env.module, name)) do
        @moduledoc false
        use Snmp.Mib.TextualConvention, mapping: unquote(values)
      end
    end
  end
end
