defmodule Snmp.Agent do
  @moduledoc """
  Manages SNMP agent
  """
  use GenServer

  defstruct port: nil, mibs: []

  @type mib_path :: Path.t() | {atom(), Path.t()}
  @type start_arg :: {:enable, :boolean} | {:port, integer()} | {:mibs, [mib_path()]}
  @type start_args :: [start_arg()]

  @args [:port, :mibs]

  @doc """
  Starts SNMP agent
  """
  @spec start_link(start_args) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(args) do
    s =
      args
      |> Keyword.take(@args)
      |> (& struct!(__MODULE__, &1)).()

    {:ok, s}
  end
end
