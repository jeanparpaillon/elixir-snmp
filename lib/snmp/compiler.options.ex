defmodule Snmp.Compiler.Options do
  @moduledoc """
  Defines a structure for compiler options
  """
  defstruct srcdir: "./mibs",
            destdir: "./priv/mibs",
            includes: [],
            includes_lib: [],
            extra_opts: [],
            instrumentation: true,
            force: false

  @type t :: %__MODULE__{}

  @doc false
  def from_project(project \\ Mix.Project.config()) do
    struct!(__MODULE__, project[:snmpc_opts] || [])
  end

  @doc false
  def to_snmpc(opts) do
    includes =
      (opts.includes ++ [opts.destdir])
      |> Enum.map(&to_charlist/1)

    snmpc_opts = [
      {:outdir, '#{opts.destdir}'},
      {:i, includes},
      {:il, opts.includes_lib},
      :imports | opts.extra_opts
    ]

    if opts.instrumentation do
      snmpc_opts
    else
      [{:module, Fake} | snmpc_opts]
    end
  end
end
