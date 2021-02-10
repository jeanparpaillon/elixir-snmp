defmodule Snmp.Agent do
  @moduledoc """
  Manages SNMP agent

  The only parameter is a configuration callback module, implementing
  `Snmp.Agent.Handler` behaviour.
  """
  use GenServer

  require Logger

  defstruct handler: nil, errors: [], config: %{}, overwrite: false

  @typedoc "Module implementing `Snmp.Agent.Handler` behaviour"
  @type handler :: module()

  @default_agent_env [
    versions: [:v1, :v2],
    multi_threaded: true,
    mib_server: []
  ]

  @default_net_if_env [
    module: :snmpa_net_if
  ]

  @configs [
    agent_conf: "agent.conf",
    context_conf: "context.conf",
    standard_conf: "standard.conf",
    community_conf: "community.conf",
    vacm_conf: "vacm.conf",
    usm_conf: "usm.conf",
    notify_conf: "notify.conf",
    target_conf: "target_addr.conf",
    target_params_conf: "target_params.conf"
  ]

  # Logger to SNMP agent verbosity mapping
  # Logger:  :emergency | :alert | :critical | :error | :warning | :warn | :notice | :info | :debug
  # SNMP: silence | info | log | debug | trace
  @verbosity %{
    debug: :debug,
    info: :log,
    notice: :log,
    warn: :info,
    warning: :info,
    error: :silence,
    critical: :silence,
    alert: :silence,
    emergency: :silence
  }

  @doc """
  Starts SNMP agent
  """
  @spec start_link(handler) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(handler) do
    s = %__MODULE__{handler: handler}

    case build_config(s) do
      %{errors: []} = s ->
        _ = :snmp.start_agent(:normal)
        {:ok, s, {:continue, :load_mibs}}

      %{errors: errors} ->
        {:stop, errors}
    end
  end

  @impl GenServer
  def handle_continue(:load_mibs, s) do
    # TODO
    {:noreply, s}
  end

  ###
  ### Priv
  ###
  defp build_config(s) do
    s
    |> ensure_db_dir()
    |> ensure_conf_dir()
    |> verbosity()
    |> when_valid?(&agent_env/1)
    |> when_valid?(&agent_conf/1)
    # |> when_valid?(&context_conf/1)
    # |> when_valid?(&standard_conf/1)
    # |> when_valid?(&community_conf/1)
    # |> when_valid?(&vacm_conf/1)
    # |> when_valid?(&usm_conf/1)
    # |> when_valid?(&notify_conf/1)
    # |> when_valid?(&target_conf/1)
    |> when_valid?(&commit/1)
  end

  defp ensure_db_dir(s) do
    db_dir = cb(s, :db_dir)

    case File.mkdir_p(db_dir) do
      :ok -> put_config(s, :db_dir, '#{db_dir}')
      {:error, err} -> error(s, "can not create db_dir: #{err}")
    end
  end

  defp ensure_conf_dir(s) do
    conf_dir = cb(s, :conf_dir)

    case File.mkdir_p(conf_dir) do
      :ok -> put_config(s, :conf_dir, '#{conf_dir}')
      {:error, err} -> error(s, "can not create conf_dir: #{err}")
    end
  end

  defp verbosity(s) do
    verbosity = Map.get(@verbosity, Logger.level())
    put_config(s, :verbosity, verbosity)
  end

  defp agent_env(s) do
    env =
      @default_agent_env
      |> Keyword.merge(
        db_dir: fetch_config!(s, :db_dir),
        config: [dir: fetch_config!(s, :conf_dir)],
        agent_verbosity: fetch_config!(s, :verbosity)
      )
      |> Keyword.merge(cb(s, :agent_env))

    net_if_env =
      @default_net_if_env
      |> Keyword.merge(verbosity: fetch_config!(s, :verbosity))
      |> Keyword.merge(cb(s, :net_if_env))

    put_config(s, :agent_env, [{:net_if, net_if_env} | env])
  end

  defp agent_conf(s) do
    {transports, port} =
      s
      |> cb(:net_conf)
      |> case do
        {addresses, port} ->
          {cast_addresses(List.wrap(addresses)), port}

        port when is_integer(port) ->
          {cast_addresses([{0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0, 0}]), port}
      end

    agent_conf =
      [
        intAgentUDPPort: port,
        intAgentTransports: transports
      ]
      |> Keyword.merge(cb(s, :snmp_framework_mib))

    s
    |> put_config(:agent_conf, agent_conf)
    |> validate_required(:agent_conf, [:snmpEngineID, :snmpEngineMaxMessageSize])
  end

  defp commit(s) do
    :ok = Application.put_env(:snmp, :agent, get_config(s, :agent_env))

    @configs
    |> Enum.reduce(s, fn {name, file}, acc ->
      case write_config(s, name, file) do
        {:ok, _} -> acc
        {:error, error} -> error(acc, error)
      end
    end)
  end

  defp write_config(s, name, file) do
    path = config_path(s, file)

    terms =
      s
      |> get_config(name)
      |> case do
        nil -> []
        config -> config
      end

    case write_terms(path, terms, s.overwrite) do
      :ok -> {:ok, name}
      {:error, error} -> {:error, error}
    end
  end

  defp config_path(s, path) do
    s |> get_config(:conf_dir) |> Path.join(path)
  end

  defp fetch_config!(s, key), do: Map.fetch!(s.config, key)

  defp get_config(s, key), do: Map.get(s.config, key)

  defp put_config(s, key, value) do
    %{s | config: Map.put(s.config, key, value)}
  end

  defp cb(%{handler: handler}, f, a \\ []), do: apply(handler, f, a)

  defp error(s, err), do: %{s | errors: s.errors ++ [err]}

  defp when_valid?(%{errors: []} = s, fun), do: fun.(s)

  defp when_valid?(s, _fun), do: s

  defp write_terms(path, terms, overwrite) do
    unless file_ok(path, overwrite) do
      data = Enum.map(terms, &:io_lib.format('~tp.~n', [&1]))
      File.write(path, data)
    else
      :ok
    end
  end

  defp file_ok(_, true), do: false

  defp file_ok(path, false) do
    with true <- File.exists?(path),
         {:ok, terms} when terms != [] <- :file.consult('#{path}') do
      # File OK
      true
    else
      false ->
        # File missing
        false

      {:ok, []} ->
        # File empty
        false

      {:error, _} ->
        # File corrupted
        false
    end
  end

  defp cast_addresses(addresses) do
    Enum.map(addresses, fn
      {_, _, _, _} = a -> {:transportDomainUdpIpv4, a}
      {_, _, _, _, _, _, _, _} = a -> {:transportDomainUdpIpv6, a}
    end)
  end

  defp validate_required(s, section, required) do
    keys =
      s
      |> get_config(section)
      |> Keyword.keys()
      |> Enum.uniq()

    case required -- keys do
      [] -> s
      missing -> error(s, "missing keys in #{section}: #{inspect missing}")
    end
  end
end
