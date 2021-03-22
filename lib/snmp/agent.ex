defmodule Snmp.Agent do
  @moduledoc """
  Use this module to generate an Agent module you can insert in your supervision
  tree.

  ## DSL

  See `Snmp.Agent.DSL`.

  ## Configuration

  When using this module, you need to provide `:otp_app` option. Agent
  environment will be get with: `Application.get_env(<otp_app>,
  <agent_module>)`.

  * `versions` (optional, default: `[:v3]`): a list of versions to enable for
    this agent amongst `:v1`, `v2` and `v3`.
  * `transports` (optional, default: `["127.0.0.1", "::1"]`): a list of possible
    transports definitions. See `t:Snmp.Transport.agent_transport/0`.
  * `security`: defines a list of users. See `t:Snmp.Mib.UserBasedSm.user/0` for format.

  ## Example

    ```
    defmodule Agent do
      use Snmp.Agent, otp_app: :my_app

      # Mandatory MIBs
      mib MyApp.Mib.Standard
      mib MyApp.Mib.Framework

      # Application MIBs
      mib MyMib

      # VACM model
      view :public do
        include [1, 3, 6, 1, 2, 1]
      end

      view :private do
        include [1, 3, 6]
      end

      access :public,
        versions: [:v1, :v2c, :usm],
        level: :noAuthNoPriv,
        read_view: :public

      access :secure,
        versions: [:usm],
        level: :authPriv,
        read_view: :private,
        write_view: :private,
        notify_view: :private
    end
    ```
  """
  use GenServer

  require Logger

  alias Snmp.Agent.Config

  defstruct handler: nil, errors: [], config: %{}, overwrite: true, otp_app: nil

  @type handler :: module()

  @doc """
  Generates an SNMP agent module
  """
  defmacro __using__(args) do
    quote do
      use Snmp.Agent.Handler, unquote(args)
    end
  end

  @doc """
  Starts SNMP agent
  """
  @spec start_link(handler) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
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
end
