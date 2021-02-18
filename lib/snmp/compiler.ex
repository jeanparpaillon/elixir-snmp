defmodule Snmp.Compiler do
  @moduledoc """
  Functions for compiling MIBs
  """
  require Record

  alias Snmp.Compiler.Options
  alias Snmp.Mib

  # From `snmp/src/compile/snmpc.hrl`
  Record.defrecordp(:pdata, mib_version: nil, mib_name: nil, imports: nil, defs: nil)

  @type opts :: Snmp.Compiler.Options.t()

  @doc """
  Compiles given MIBs
  """
  @spec run([Path.t()], opts) :: {:ok, [Path.t()]} | {:error, term()}
  def run(sources, opts) do
    sources
    |> Enum.reduce({[], []}, fn src, {mibs, errors} ->
      target = target(src, opts)

      case do_compile(src, opts, opts.force || Mix.Utils.stale?([src], [target])) do
        {:ok, dest} -> {[dest | mibs], errors}
        {:error, error} -> {mibs, [error | errors]}
      end
    end)
    |> case do
      {mibs, []} ->
        {:ok, Enum.reverse(mibs)}

      {_, errors} ->
        {:error, errors |> List.wrap() |> Enum.reverse()}
    end
  end

  @doc """
  Compiles and returns MIB (AST)
  """
  @spec mib(String.Chars.t(), Options.t()) :: {:ok, Mib.t()} | {:error, term()}
  def mib(name, opts) do
    src = find_mib(opts, "#{name}" <> ".mib")

    with {:ok, [dest]} <- run([src], opts) do
      :snmpc_misc.read_mib('#{dest}')
    end
  end

  @doc """
  Returns given source's dependencies (imports)
  """
  @spec dependencies(Path.t(), Options.t()) :: {:ok, [String.t()]} | {:error, term()}
  def dependencies(source, opts) do
    source
    |> Mib.Parser.from_file()
    |> case do
      {:ok, pdata} ->
        {:ok, extract_imports(pdata, opts)}

      {:error, error} ->
        {:error, error}
    end
  end

  ###
  ### Priv
  ###
  defp target(src, opts) do
    Path.join(opts.destdir, Path.basename(src, ".mib") <> ".bin")
  end

  defp do_compile(src, opts, false) do
    {:ok, target(src, opts)}
  end

  defp do_compile(src, opts, true) do
    _ = ensure_destdir(opts)

    src = Path.join(Path.dirname(src), Path.basename(src, ".mib"))
    :snmpc.compile('#{src}', Options.to_snmpc(opts))
  end

  defp ensure_destdir(opts) do
    _ = File.mkdir_p!(opts.destdir)
  end

  defp extract_imports(pdata, opts) do
    pdata
    |> pdata(:imports)
    |> Enum.reduce([], &filter_type_import/2)
    |> Enum.reduce([], &expand_source_path(&1, &2, opts))
  end

  defp filter_type_import({{mib, imports}, _line}, acc) do
    case Enum.filter(imports, &(elem(&1, 0) == :type)) do
      [] -> acc
      _types -> [mib | acc]
    end
  end

  defp expand_source_path(mibname, acc, opts) do
    # If MIB is not in `srcdir`, just ignore, compiler will complain later
    path = opts.srcdir |> Path.join("#{mibname}.mib") |> Path.expand()

    if File.exists?(path) do
      [path | acc]
    else
      acc
    end
  end

  defp find_mib(opts, filename) do
    [opts.srcdir, Application.app_dir(:snmp, "mibs")]
    |> Enum.map(&Path.join(&1, filename))
    |> Enum.find(&File.exists?/1)
  end
end
