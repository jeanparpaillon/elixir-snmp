defmodule Snmp.Mib do
  @moduledoc """
  Generates module from MIB

  # Enumerations

  Generates `Snmp.MIB.TextualConvention` modules from enumerations

  # Ranges

  Generates `__range__/1`: returns `{low_value, high_value}` from name

  # Defaults

  Generates `__default__/1`: returns default value from name, or nil
  """
  alias Snmp.Mib.TableInfo

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

  @type name :: atom() | charlist() | String.t()

  @type t ::
          record(:mib,
            misc: term(),
            mib_format_version: term(),
            name: term(),
            module_identity: term(),
            mes: term(),
            asn1_types: term(),
            traps: term(),
            variable_infos: term(),
            imports: term()
          )

  alias Snmp.Compiler

  @doc false
  defmacro __using__(opts) do
    default_instr_opts = [caller: __CALLER__.module]
    gen_table_modules = false

    {instr_mod, instr_opts} =
      opts
      |> Keyword.get(:instrumentation, __CALLER__.module)
      |> Macro.expand(__CALLER__)
      |> case do
        mod when is_atom(mod) ->
          {mod, default_instr_opts}

        {mod, opts} when is_list(opts) ->
          {mod, Keyword.merge(default_instr_opts, opts)}
      end

    name = Keyword.fetch!(opts, :name)
    snmpc_opts = Compiler.Options.from_project()

    snmpc_opts = %{
      snmpc_opts
      | extra_opts: [{:module, __CALLER__.module} | snmpc_opts.extra_opts],
        force: true
    }

    {:ok, mib} = Compiler.mib(name, snmpc_opts)

    table_infos = Enum.map(mib(mib, :table_infos), &TableInfo.new(&1, mib))

    if Keyword.get(opts, :debug, false) do
      path = Macro.escape(name) <> ".exs"
      Mix.shell().info("Dump MIB into #{path}")
      File.write!("./#{path}", inspect(mib, limit: :infinity, pretty: true))
    end

    [
      quote do
        @instrumentation {unquote(instr_mod), unquote(instr_opts)}

        @mib_name :"#{unquote(name)}"

        Module.register_attribute(__MODULE__, :variable, accumulate: true)
        Module.register_attribute(__MODULE__, :table, accumulate: true)
        Module.register_attribute(__MODULE__, :oid, accumulate: true)
        Module.register_attribute(__MODULE__, :range, accumulate: true)
        Module.register_attribute(__MODULE__, :default, accumulate: true)
        Module.register_attribute(__MODULE__, :enum, accumulate: true)
        Module.register_attribute(__MODULE__, :bits, accumulate: true)
        Module.register_attribute(__MODULE__, :table_info, accumulate: true)
        Module.register_attribute(__MODULE__, :ecto_type, accumulate: true)

        @before_compile Snmp.Mib
        @before_compile Snmp.Instrumentation
      end
    ] ++
      Enum.map(mib(mib, :asn1_types), &parse_asn1_type/1) ++
      Enum.map(mib(mib, :mes), &parse_me(&1, __CALLER__)) ++
      Enum.map(table_infos, fn %{table_name: table} = infos ->
        quote do
          @table_info {unquote(table), unquote(Macro.escape(infos))}
        end
      end) ++
      if gen_table_modules do
        Enum.map(table_infos, &gen_table_module(&1, __CALLER__))
      else
        []
      end
  end

  defmacro __before_compile__(env) do
    enums = env.module |> Module.get_attribute(:enum, [])
    bits = env.module |> Module.get_attribute(:bits, [])
    ranges = env.module |> Module.get_attribute(:range, [])
    defaults = env.module |> Module.get_attribute(:default, [])

    Enum.map(enums, &gen_enum(&1, env)) ++
      Enum.map(bits, &gen_bits(&1, env)) ++
      Enum.map(ranges, &gen_range/1) ++
      [
        quote do
          def __range__(_), do: nil
        end
      ] ++
      Enum.map(defaults, &gen_default/1) ++
      [
        quote do
          def __default__(_), do: nil
        end
      ] ++ [gen_mib(env), gen_ecto_types(env)]
  end

  ###
  ### (phase 1) extract MIB records into module attributes
  ###
  defp parse_asn1_type(asn1_type(imported: false, aliasname: name, assocList: alist)) do
    case Keyword.get(alist, :enums) do
      nil ->
        []

      enums ->
        quote do
          @enum {unquote(name), unquote(enums)}
        end
    end
  end

  defp parse_asn1_type(_), do: []

  defp parse_me(me, env) do
    []
    |> parse_oid(me)
    |> parse_range(me)
    |> parse_default(me)
    |> parse_enum(me, env)
    |> parse_bits(me, env)
    |> parse_variable(me, env)
    |> parse_table(me, env)
    |> set_ecto_type(me, env)
  end

  defp parse_oid(ast, me(oid: oid, aliasname: name)) do
    ast ++
      [
        quote do
          @oid {unquote(oid), unquote(name)}
        end
      ]
  end

  defp parse_range(ast, me(asn1_type: asn1_type(lo: :undefined))), do: ast

  defp parse_range(ast, me(asn1_type: asn1_type(hi: :undefined))), do: ast

  defp parse_range(
         ast,
         me(asn1_type: asn1_type(bertype: bertype, lo: lo, hi: hi), aliasname: name)
       )
       when bertype in [:"OCTET-STRING", :Unsigned32, :Counter32, :INTEGER] do
    ast ++
      [
        quote do
          @range {unquote(name), unquote(lo), unquote(hi)}
        end
      ]
  end

  defp parse_range(ast, _), do: ast

  defp parse_default(ast, me(entrytype: :table_column, assocList: alist, aliasname: name)) do
    case Keyword.get(alist, :defval) do
      nil ->
        ast

      defval ->
        ast ++
          [
            quote do
              @default {unquote(name), unquote(defval)}
            end
          ]
    end
  end

  defp parse_default(ast, me(entrytype: :variable, assocList: alist, aliasname: name)) do
    case Keyword.get(alist, :variable_info) do
      nil ->
        ast

      variable_info(defval: :undefined) ->
        ast

      variable_info(defval: defval) ->
        ast ++
          [
            quote do
              @default {unquote(name), unquote(defval)}
            end
          ]
    end
  end

  defp parse_default(ast, _), do: ast

  defp parse_enum(
         ast,
         me(imported: false, aliasname: name, asn1_type: asn1_type(assocList: alist)),
         env
       ) do
    case Keyword.get(alist, :enums) do
      nil ->
        ast

      enums ->
        ast ++
          [
            quote do
              @enum {unquote(name), unquote(enums)}
              @ecto_type {unquote(name), unquote(gen_type_modname(env, name))}
            end
          ]
    end
  end

  defp parse_enum(ast, _, _), do: ast

  defp parse_bits(
         ast,
         me(
           imported: false,
           aliasname: name,
           asn1_type: asn1_type(bertype: :BITS, assocList: alist)
         ),
         _
       ) do
    case Keyword.get(alist, :kibbles) do
      nil ->
        ast

      kibbles ->
        ast ++
          [
            quote do
              @bits {unquote(name), unquote(kibbles)}
            end
          ]
    end
  end

  defp parse_bits(ast, _, _), do: ast

  defp set_ecto_type(
         ast,
         me(
           imported: false,
           aliasname: name,
           asn1_type: asn1_type(bertype: :INTEGER, assocList: alist)
         ),
         env
       ) do
    case Keyword.get(alist, :enums) do
      nil ->
        ast

      _enums ->
        ast ++
          [
            quote do
              @ecto_type {unquote(name), unquote(gen_type_modname(env, name))}
            end
          ]
    end
  end

  defp set_ecto_type(
         ast,
         me(
           imported: false,
           aliasname: name,
           asn1_type: asn1_type(bertype: :BITS, assocList: alist)
         ),
         env
       ) do
    case Keyword.get(alist, :kibbles) do
      nil ->
        ast

      _kibbles ->
        ast ++
          [
            quote do
              @ecto_type {unquote(name), unquote(gen_type_modname(env, name))}
            end
          ]
    end
  end

  defp set_ecto_type(ast, _, _) do
    # _TODO
    ast
  end

  defp parse_variable(ast, me(aliasname: name, entrytype: :variable) = e, _env) do
    ast ++
      [
        quote do
          @variable {unquote(name), unquote(Macro.escape(e))}
        end
      ]
  end

  defp parse_variable(ast, _, _), do: ast

  defp parse_table(ast, me(aliasname: name, entrytype: :table) = e, _env) do
    ast ++
      [
        quote do
          @table {unquote(name), unquote(Macro.escape(e))}
        end
      ]
  end

  defp parse_table(ast, _, _), do: ast

  ###
  ### (phase 2) translate module attributes into functions/modules
  ###
  defp gen_enum({name, values}, env) do
    quote do
      defmodule unquote(gen_type_modname(env, Macro.escape(name))) do
        @moduledoc false
        use Snmp.Mib.TextualConvention, mapping: unquote(Macro.escape(values))
      end
    end
  end

  defp gen_bits({name, kibbles}, env) do
    quote do
      defmodule unquote(gen_type_modname(env, Macro.escape(name))) do
        @moduledoc false
        use Snmp.Mib.Bits, kibbles: unquote(Macro.escape(kibbles))
      end
    end
  end

  defp gen_ecto_types(_env) do
    quote do
      use Ecto.ParameterizedType

      def init(params) do
        type = Keyword.fetch!(params, :type_of)

        case Map.get(__mib__(:ecto_types), type) do
          nil -> raise "Invalid type #{type}"
          _ -> :ok
        end

        Enum.into(params, %{})
      end

      def type(%{type_of: type}),
        do: apply(__mib__(:ecto_types)[type], :type, [])

      def cast(nil, %{default: default}), do: {:ok, default}

      def cast(value, %{type_of: type}),
        do: apply(__mib__(:ecto_types)[type], :cast, [value])

      def load(value, _loader, %{type_of: type}),
        do: apply(__mib__(:ecto_types)[type], :load, [value])

      def dump(value, _dumper, %{type_of: type}),
        do: apply(__mib__(:ecto_types)[type], :dump, [value])

      def embed_as(format, %{type_of: type}),
        do: apply(__mib__(:ecto_types)[type], :embed_as, [format])

      def equal?(value1, value2, %{type_of: type}),
        do: apply(__mib__(:ecto_types)[type], :equal?, [value1, value2])
    end
  end

  defp gen_range({name, lo, hi}) do
    quote do
      def __range__(unquote(name)), do: {unquote(lo), unquote(hi)}
    end
  end

  defp gen_default({name, default}) do
    quote do
      def __default__(unquote(name)), do: unquote(default)
    end
  end

  defp gen_mib(env) do
    oids =
      env.module
      |> Module.get_attribute(:oid, [])
      |> Enum.reduce(%{}, fn {oid, name}, acc ->
        Map.put(acc, name, oid)
      end)

    variables = env.module |> Module.get_attribute(:variable, []) |> Enum.into(%{})

    varfuns =
      env.module
      |> Module.get_attribute(:variable, [])
      |> Enum.map(&elem(&1, 1))
      |> Enum.flat_map(fn me(mfa: {_, f, _}) -> [{f, 1}, {f, 2}] end)

    tablefuns =
      env.module
      |> Module.get_attribute(:table, [])
      |> Enum.map(&elem(&1, 1))
      |> Enum.flat_map(fn me(aliasname: aliasname) -> [{aliasname, 1}, {aliasname, 3}] end)

    mibname = env.module |> Module.get_attribute(:mib_name)
    extra = env.module |> Module.get_attribute(:mib_extra, [])

    table_infos = env.module |> Module.get_attribute(:table_info, []) |> Enum.into(%{})

    ecto_types = env.module |> Module.get_attribute(:ecto_type, []) |> Enum.into(%{})

    [
      quote do
        def __mib__(:oids), do: unquote(Macro.escape(oids))

        def __mib__(:variables), do: unquote(Macro.escape(variables))

        def __mib__(:varfuns), do: unquote(Macro.escape(varfuns))

        def __mib__(:tablefuns), do: unquote(Macro.escape(tablefuns))

        def __mib__(:name), do: unquote(Macro.escape(mibname))

        def __mib__(:table_infos), do: unquote(Macro.escape(table_infos))
      end
    ] ++
      Enum.map(extra, fn {key, value} ->
        quote do
          def __mib__(unquote(key)), do: unquote(value)
        end
      end) ++
      [
        quote do
          def __mib__(:ecto_types), do: unquote(Macro.escape(ecto_types))
        end
      ]
  end

  defp gen_table_module(%{table_name: table} = infos, env) do
    mod_name = Module.concat(env.module, Macro.camelize(Atom.to_string(infos.entry_name)))

    quote do
      defmodule unquote(mod_name) do
        use Snmp.ASN1.TableEntry, {unquote(table), unquote(infos)}
      end
    end
  end

  defp gen_type_modname(env, type) do
    type =
      case type |> to_charlist() |> hd() do
        i when i >= ?A and i <= ?Z -> type
        _ -> String.capitalize("#{type}")
      end

    Module.concat(env.module, type)
  end
end
