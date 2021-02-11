defmodule Snmp.Agent do
  @moduledoc """
  Manages SNMP agent

  The only parameter is a configuration callback module, implementing
  `Snmp.Agent.Handler` behaviour.
  """
  use GenServer

  require Logger

  defstruct handler: nil, errors: [], config: %{}, overwrite: true

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

  @public_sec 'publicSec'
  @private_sec 'privateSec'
  @trap_sec 'trapSec'

  @public_group 'publicGroup'
  @private_group 'privateGroup'

  @notify_tag 'notify'

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
  @spec stream(:snmpa.oid()) :: Stream.t()
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
  @spec oid_to_dot(:snmpa.oid()) :: String.t()
  def oid_to_dot(oid) when is_list(oid) do
    oid
    |> oid_to_names([])
    |> Enum.join(".")
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
    |> when_valid?(&context_conf/1)
    |> when_valid?(&standard_conf/1)
    |> when_valid?(&community_conf/1)
    |> when_valid?(&vacm_conf/1)
    |> when_valid?(&usm_conf/1)
    |> when_valid?(&notify_conf/1)
    |> when_valid?(&target_conf/1)
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

    framework_values =
      take_mib(s, :framework_mib, [
        :snmpEngineID,
        :snmpEngineBoots,
        :snmpEngineTime,
        :snmpEngineMaxMessageSize
      ])

    agent_conf =
      [
        intAgentUDPPort: port,
        intAgentTransports: transports
      ]
      |> Keyword.merge(framework_values)

    s
    |> put_config(:agent_conf, agent_conf)
    |> validate_required(:agent_conf, [:snmpEngineID, :snmpEngineMaxMessageSize])
  end

  defp context_conf(s) do
    contexts =
      if :v3 in versions(s) do
        s
        |> cb(:contexts)
        |> Enum.map(&to_charlist/1)
      else
        []
      end

    s
    |> put_config(:context_conf, contexts)
  end

  defp standard_conf(s) do
    values =
      take_mib(s, :standard_mib, [
        :sysName,
        :sysDescr,
        :sysContact,
        :sysLocation,
        :sysObjectID,
        :sysServices,
        :snmpEnableAuthenTraps
      ])

    s
    |> put_config(:standard_conf, values)
  end

  defp community_conf(s) do
    community = [
      {'public', 'public', @public_sec, '', ''},
      {'private', 'private', @private_sec, '', ''},
      {'trap', 'trap', @trap_sec, '', ''}
    ]

    s
    |> put_config(:community_conf, community)
  end

  defp vacm_conf(s) do
    vacm_conf = [
      {:vacmSecurityToGroup, :usm, @public_sec, @public_group},
      {:vacmSecurityToGroup, :usm, @private_sec, @private_group},
      {:vacmSecurityToGroup, :v2c, @public_sec, @public_group},
      {:vacmSecurityToGroup, :v2c, @private_sec, @private_group},
      {:vacmSecurityToGroup, :v1, @public_sec, @public_group},
      {:vacmSecurityToGroup, :v1, @private_sec, @private_group},
      {:vacmAccess, @public_group, '', :v1, :noAuthNoPriv, :exact, 'internet', '', 'restricted'},
      {:vacmAccess, @public_group, '', :v2c, :noAuthNoPriv, :exact, 'internet', '', 'restricted'},
      {:vacmAccess, @public_group, '', :usm, :noAuthNoPriv, :exact, 'internet', '', 'restricted'},
      {:vacmAccess, @private_group, '', :v1, :noAuthNoPriv, :exact, 'restricted', 'restricted',
       'restricted'},
      {:vacmAccess, @private_group, '', :v2c, :noAuthNoPriv, :exact, 'restricted', 'restricted',
       'restricted'},
      {:vacmAccess, @private_group, '', :usm, :authNoPriv, :exact, 'restricted', 'restricted',
       'restricted'},
      {:vacmAccess, @private_group, '', :v1, :noAuthNoPriv, :exact, 'restricted', 'restricted',
       'restricted'},
      {:vacmAccess, @private_group, '', :v2c, :noAuthNoPriv, :exact, 'restricted', 'restricted',
       'restricted'},
      {:vacmAccess, @private_group, '', :usm, :authPriv, :exact, 'restricted', 'restricted',
       'restricted'},
      {:vacmViewTreeFamily, 'internet', [1, 3, 6, 1, 2, 1], :included, :null},
      {:vacmViewTreeFamily, 'restricted', [1, 3, 6, 1], :included, :null}
    ]

    s
    |> put_config(:vacm_conf, vacm_conf)
  end

  defp usm_conf(s) do
    usm_conf = [
      {'agent', '', 'publicSec', :zeroDotZero, :usmNoAuthProtocol, '', '', :usmNoPrivProtocol, '',
       '', '', '', ''},
      {'agent', 'admin', 'privateSec', :zeroDotZero, :usmHMACMD5AuthProtocol, '', '',
       :usmNoPrivProtocol, '', '', '',
       [69, 162, 150, 62, 179, 98, 234, 173, 133, 128, 124, 29, 219, 216, 70, 165], ''}
    ]

    s
    |> put_config(:usm_conf, usm_conf)
  end

  defp notify_conf(s) do
    notify_conf = [
      {'target1_v1', @notify_tag, :trap},
      {'target1_v2', @notify_tag, :trap},
      {'target1_v3', @notify_tag, :trap},
      {'target2_v1', @notify_tag, :trap},
      {'target2_v2', @notify_tag, :trap},
      {'target2_v3', @notify_tag, :trap},
      {'target3_v1', @notify_tag, :trap},
      {'target3_v2', @notify_tag, :trap},
      {'target3_v3', @notify_tag, :trap}
    ]

    s
    |> put_config(:notify_conf, notify_conf)
  end

  defp target_conf(s) do
    target_conf = []

    target_params_conf = [
      {'target_v1', :v1, :v1, @public_sec, :noAuthNoPriv},
      {'target_v2', :v2c, :v2c, @public_sec, :noAuthNoPriv},
      {'target_v3', :v3, :usm, @public_sec, :noAuthNoPriv}
    ]

    s
    |> put_config(:target_conf, target_conf)
    |> put_config(:target_params_conf, target_params_conf)
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
      missing -> error(s, "missing keys in #{section}: #{inspect(missing)}")
    end
  end

  defp take_mib(s, name, keys) do
    mib = cb(s, name)

    keys
    |> Enum.reduce([], fn varname, acc ->
      try do
        case apply(mib, varname, [:get]) do
          {:value, value} -> [{varname, value} | acc]
          _ -> acc
        end
      rescue
        UndefinedFunctionError -> acc
      end
    end)
    |> Enum.map(fn
      {k, v} when is_binary(v) -> {k, to_charlist(v)}
      {k, v} -> {k, v}
    end)
  end

  defp versions(s) do
    s
    |> get_config(:agent_env)
    |> Keyword.get(:versions, @default_agent_env[:versions])
  end

  defp oid_to_names([], acc), do: acc

  defp oid_to_names([1,3,6,1,2], acc), do: acc

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
