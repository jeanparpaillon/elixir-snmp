defmodule Mix.Tasks.Compile.Mib do
  @moduledoc """
  MIBs compiler

  `:snmpc` expects instrumentation functions to be defined when parsing MIBs.

  This libraries provides macros for generating instrumentation modules out of
  MIB file (see `Snmp.Mib`). When compiling instrumentation module, we need MIB
  to be parsed, as well as its dependencies.

  This module compiles MIB into `*.bin` with fake instrumentation. `Snmp.Mib`
  will recompile `.mib` file into `.bin` with proper instrumentation
  declaration.

  ## Configuration

    * `:snmpc_opts` - compilation options for the compiler. See below for
      options.

    Options:
    * `:srcdir` - directory where to find '*.mib' files. Defaults to `"mibs"`
    * `:destdir` - directory to put generated files. Default to `"priv/mibs"`
    * `:includes` - directories to look for imported definitions, in addition to
      `:srcdir`. Default to `[]`
    * `:includes_lib` - application directories to look for other mibs. Default
      to `[]`
    * `:extra_opts` - any extra option to pass to snmpc compiler
  """
  @shortdoc "Compile MIB files"

  @task_name "compile.mib"

  use Mix.Task.Compiler

  alias Snmp.Compiler.Options

  @doc false
  def run(_args) do
    opts = Options.from_project()
    opts = %{opts | instrumentation: false}

    opts
    |> sources()
    |> sort_dependencies(opts)
    |> Snmp.Compiler.run(opts)
    |> case do
      {:ok, _} ->
        :ok

      {:error, error} ->
        error
        |> List.wrap()
        |> Enum.each(&error/1)

        {:error, error}
    end
  end

  @doc false
  def clean do
    opts = Options.from_project()

    opts
    |> targets()
    |> case do
      [] ->
        :ok

      paths ->
        info("cleanup " <> Enum.join(paths, " "))
        Enum.each(paths, &File.rm/1)
    end
  end

  ###
  ### Priv
  ###
  defp info(msg) do
    Mix.shell().info([:bright, @task_name, :normal, " ", msg])
  end

  defp error(msg) when is_binary(msg) do
    Mix.shell().info([:bright, @task_name, :normal, " ", :red, msg])
  end

  defp error(err),
    do: err |> inspect() |> error()

  defp sources(%{srcdir: srcdir}) do
    srcdir
    |> Path.join("*.mib")
    |> Path.wildcard()
    |> Enum.map(&Path.expand/1)
  end

  defp targets(%{destdir: destdir}) do
    destdir
    |> Path.join("*.bin")
    |> Path.wildcard()
    |> Enum.map(&Path.expand/1)
  end

  defp sort_dependencies(sources, opts) do
    graph = :digraph.new()

    _ =
      for src <- sources do
        :digraph.add_vertex(graph, src)
      end

    _ =
      for src <- sources do
        case Snmp.Compiler.dependencies(src, opts) do
          {:ok, deps} ->
            for dep <- deps do
              :digraph.add_edge(graph, dep, src)
            end

          {:error, error} ->
            raise error
        end
      end

    result =
      case :digraph_utils.topsort(graph) do
        false ->
          sources

        ordered ->
          ordered
      end

    :digraph.delete(graph)

    result
  end
end
