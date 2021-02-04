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
  defmacro __using__(opts) do
    mib = Keyword.get_lazy(opts, :name, fn -> raise "Missing option :name for Snmp.Mib" end)
    reqs = Keyword.get(opts, :requires, [])
    Enum.each(reqs, &({:ok, _} = compile_mib(&1, [])))

    {:ok, bin_path} = Snmp.Mib.compile_mib(mib, [{:module, __CALLER__.module}])
    {:ok, mib} = :snmpc_misc.read_mib(bin_path)

    q_mib = Macro.escape(mib)

    quote do
      require Record

      @mib unquote(q_mib)
      @varfuns []
      @tablefuns []

      Snmp.Mib.include(unquote(mib))
    end
  end

  defmacro include(mib) do
      mib
      |> mib(:asn1_types)
      |> Enum.reduce([], fn
        asn1_type(imported: false, aliasname: name, assocList: [enums: enums]), acc
        when enums != [] ->
          [mib_enum(Module.concat([__CALLER__.module, name]), enums) | acc]

        _type, acc ->
          acc
      end)
  end

  def compile_mib(mib, opts) do
    project = Mix.Project.config()
    mib_src = Path.join(["mibs", mib <> ".mib"])
    mib_dest = Path.join([Mix.Project.app_path(project), "priv", "mibs", mib <> ".bin"])
    do_compile_mib(mib_src, mib_dest, opts, Mix.Utils.stale?([mib_src], [mib_dest]))
  end

  def do_compile_mib(_src, dest, _opts, false), do: {:ok, dest}

  def do_compile_mib(src, dest, opts, true) do
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

    :snmpc.compile('#{src}', opts)
  end

  defp mib_enum(name, enums) do
    quote do
      defmodule unquote(name) do
        use Snmp.Mib.TextualConvention, mapping: unquote(enums)
      end
    end
  end
end
