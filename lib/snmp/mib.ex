defmodule Snmp.Mib do
  @moduledoc """
  Generates module from MIB

  # Enumerations

  Generates `Snmp.MIB.TextualConvention` modules from enumerations

  # OIDs

  Generates the following functions:
  * `__oid__/1`: returns OID from name
  * `__oname__/1`: returns name from OID
  * `__oids__/0`: returns name/OID full map

  # Ranges

  Generates `__range__/1`: returns `{low_value, high_value}` from name

  # Defaults

  Generates `__default__/1`: returns default value from name, or nil
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
    {instr_mod, instr_opts} =
      opts
      |> Keyword.get(:instrumentation, __CALLER__.module)
      |> Macro.expand(__CALLER__)
      |> case do
        {mod, opts} -> {mod, opts}
        mod when is_atom(mod) -> {mod, nil}
      end

    name = Keyword.fetch!(opts, :name)
    opts = Compiler.Options.from_project()
    opts = %{opts | extra_opts: [{:module, instr_mod} | opts.extra_opts], force: true}

    {:ok, mib} = Compiler.mib(name, opts)

    [
      quote do
        @instrumentation {unquote(instr_mod), unquote(instr_opts)}

        @mibname unquote(name)

        Module.register_attribute(__MODULE__, :varfun, accumulate: true)
        Module.register_attribute(__MODULE__, :tablefun, accumulate: true)
        Module.register_attribute(__MODULE__, :oid, accumulate: true)
        Module.register_attribute(__MODULE__, :range, accumulate: true)
        Module.register_attribute(__MODULE__, :default, accumulate: true)
        Module.register_attribute(__MODULE__, :enum, accumulate: true)

        @before_compile Snmp.Instrumentation
        @before_compile Snmp.Mib
      end
    ] ++
      Enum.map(mib(mib, :asn1_types), &parse_asn1_type/1) ++
      Enum.map(mib(mib, :mes), &parse_me(&1, __CALLER__))
  end

  defmacro __before_compile__(env) do
    oids = env.module |> Module.get_attribute(:oid) |> Enum.uniq()
    enums = env.module |> Module.get_attribute(:enum)
    ranges = env.module |> Module.get_attribute(:range)
    defaults = env.module |> Module.get_attribute(:default)

    Enum.map(enums, &gen_enum(&1, env)) ++
      Enum.map(oids, &gen_oid/1) ++
      Enum.map(oids, &gen_oname/1) ++
      [gen_oids(oids, env)] ++
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
      ]
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
    |> parse_enum(me)
    |> parse_varfun(me, env)
    |> parse_tablefun(me, env)
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
         me(imported: false, aliasname: name, asn1_type: asn1_type(assocList: alist))
       ) do
    case Keyword.get(alist, :enums) do
      nil ->
        ast

      enums ->
        ast ++
          [
            quote do
              @enum {unquote(name), unquote(enums)}
            end
          ]
    end
  end

  defp parse_enum(ast, _), do: ast

  defp parse_varfun(ast, me(entrytype: :variable, mfa: {m, f, _}), env) do
    if m == env.module do
      ast ++
        [
          quote do
            @varfun unquote(f)
          end
        ]
    else
      []
    end
  end

  defp parse_varfun(ast, _, _), do: ast

  defp parse_tablefun(ast, me(entrytype: :table_entry, mfa: {m, f, _}), env) do
    if m == env.module do
      ast ++
        [
          quote do
            @tablefun unquote(f)
          end
        ]
    else
      ast
    end
  end

  defp parse_tablefun(ast, _, _), do: ast

  ###
  ### (phase 2) translate module attributes into functions/modules
  ###
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
end
