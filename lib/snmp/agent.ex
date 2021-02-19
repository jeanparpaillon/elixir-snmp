defmodule Snmp.Agent do
  @moduledoc """
  Manages SNMP agent

  The only parameter is a configuration callback module, implementing
  `Snmp.Agent.Handler` behaviour.
  """
  use GenServer

  require Logger

  alias Snmp.Agent.Config

  defstruct handler: nil, errors: [], config: %{}, overwrite: true, otp_app: nil

  @typedoc "Module implementing `Snmp.Agent.Handler` behaviour"
  @type handler :: module()

  @doc """
  Starts SNMP agent
  """
  @spec start_link(handler) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Returns MIB tree as stream
  """
  @spec stream(:snmp.oid()) :: Enum.t()
  def stream(oid) do
    Stream.resource(
      fn -> [oid] end,
      fn oids ->
        case :snmpa.get_next(:snmp_master_agent, oids) do
          {:error, reason} -> {:halt, {:error, reason}}
          [] -> {:halt, :ok}
          [{oid, :endOfMibView}] -> {:halt, oid}
          [{oid, value}] -> {[{oid_to_dot(oid), value}], [oid]}
        end
      end,
      fn _oid -> :ok end
    )
  end

  @doc """
  Resolve OID into dot separated names
  """
  @spec oid_to_dot(:snmp.oid()) :: String.t()
  def oid_to_dot(oid) when is_list(oid) do
    oid
    |> oid_to_names([])
    |> Enum.join(".")
  end

  @impl GenServer
  def init(handler) do
    case Config.build(handler) do
      {:ok, config} ->
        _ = :snmp.start_agent(:normal)
        {:ok, %__MODULE__{config: config}}

      {:error, errors} ->
        {:stop, errors}
    end
  end

  ###
  ### Priv
  ###
  defp oid_to_names([], acc), do: acc

  defp oid_to_names([1, 3, 6, 1, 2], acc), do: acc

  defp oid_to_names(oid, acc) do
    r_oid = Enum.reverse(oid)

    name =
      case :snmpa.oid_to_name(oid) do
        false -> "#{hd(r_oid)}"
        {:value, name} -> name
      end

    oid = r_oid |> tl() |> Enum.reverse()
    oid_to_names(oid, [name | acc])
  end
end
