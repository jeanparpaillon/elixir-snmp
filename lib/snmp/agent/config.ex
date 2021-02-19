defmodule Snmp.Agent.Config do
  @moduledoc """
  Handle agent configuration
  """
  @type t :: map()

  @dbdir "priv/snmp/agent/db"
  @confdir "priv/snmp/agent/conf"

  @default_context ''

  @default_port 4000

  @default_transports [{0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0, 0}]

  @default_agent_env [
    versions: [:v1, :v2],
    multi_threaded: true,
    mib_server: []
  ]

  @default_net_if_env [
    module: :snmpa_net_if
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

  @configs [
    agent_conf: "agent.conf",
    context_conf: "context.conf",
    #community_conf: "community.conf",
    #vacm_conf: "vacm.conf",
    #usm_conf: "usm.conf",
    #notify_conf: "notify.conf",
    #target_conf: "target_addr.conf",
    #target_params_conf: "target_params.conf"
  ]

  @doc """
  Build agent configuration
  """
  @spec build(module) :: {:ok, t()} | {:error, [term()]}
  def build(handler) do
    if Kernel.function_exported?(handler, :__agent__, 1) do
      %{errors: [], handler: handler, otp_app: apply(handler, :__agent__, [:app])}
      |> do_build()
      |> case do
        %{errors: []} = s -> {:ok, Map.drop(s, [:errors])}
        %{errors: errors} -> {:error, errors}
      end
    else
      {:error, {:no_agent, handler}}
    end
  end

  @doc """
  Write given configuration into a configuration file
  """
  @spec write_config(atom(), Path.t(), term(), boolean()) :: :ok | {:error, term()}
  def write_config(app, path, config, overwrite \\ true) do
    :ok = ensure_conf_dir(app)
    app |> conf_dir() |> Path.join(path) |> write_terms(config, overwrite)
  end

  ###
  ### Priv
  ###
  defp db_dir(app), do: Application.app_dir(app, @dbdir)

  defp conf_dir(app), do: Application.app_dir(app, @confdir)

  defp ensure_conf_dir(app), do: app |> conf_dir() |> File.mkdir_p()

  defp ensure_db_dir(app), do: app |> db_dir() |> File.mkdir_p()

  defp do_build(s) do
    s
    |> (&case ensure_conf_dir(&1.otp_app) do
      :ok -> &1
      {:error, err} -> error(&1, err)
    end).()
    |> (&case ensure_db_dir(&1.otp_app) do
      :ok -> &1
      {:error, err} -> error(&1, err)
    end).()
    |> verbosity()
    |> when_valid?(&agent_env/1)
    |> when_valid?(&agent_conf/1)
    |> when_valid?(&context_conf/1)
    |> when_valid?(&community_conf/1)
    #|> when_valid?(&vacm_conf/1)
    #|> when_valid?(&usm_conf/1)
    #|> when_valid?(&notify_conf/1)
    #|> when_valid?(&target_conf/1)
    |> when_valid?(&commit/1)
  end

  defp verbosity(s) do
    verbosity = Map.get(@verbosity, Logger.level())
    Map.put(s, :verbosity, verbosity)
  end

  defp agent_env(s) do
    env =
      @default_agent_env
      |> Keyword.merge(
        db_dir: db_dir(s.otp_app),
        config: [dir: conf_dir(s.otp_app)],
        agent_verbosity: Map.fetch!(s, :verbosity)
      )

    net_if_env =
      @default_net_if_env
      |> Keyword.merge(verbosity: Map.fetch!(s, :verbosity))

    Map.put(s, :agent_env, [{:net_if, net_if_env} | env])
  end

  defp agent_conf(s) do
    port = s.otp_app |> Application.get_env(s.handler, []) |> Keyword.get(:port, @default_port)

    transports =
      s.otp_app
      |> Application.get_env(s.handler, [])
      |> Keyword.get(:transports, [])
      |> case do
        [] -> Enum.map(@default_transports, &cast_address/1)
        addresses -> Enum.map(addresses, &cast_address/1)
      end

    framework_conf =
      s
      |> mib_mod(:"SNMP-FRAMEWORK-MIB")
      |> apply(:__mib__, [:config])

    agent_conf =
      [
        intAgentUDPPort: port,
        intAgentTransports: transports
      ]
      |> Keyword.merge(framework_conf)

    s
    |> Map.put(:agent_conf, agent_conf)
  end

  defp context_conf(s) do
    # Currently, we support only one context (default)
    contexts = [@default_context]

    s
    |> Map.put(:context_conf, contexts)
  end

  defp community_conf(s) do
    community = [
      {'public', 'public', @public_sec, '', ''},
      {'private', 'private', @private_sec, '', ''},
      {'trap', 'trap', @trap_sec, '', ''}
    ]

    s
    |> Map.put(:community_conf, community)
  end

  # defp vacm_conf(s) do
  #   vacm_conf = [
  #     {:vacmSecurityToGroup, :usm, @public_sec, @public_group},
  #     {:vacmSecurityToGroup, :usm, @private_sec, @private_group},
  #     {:vacmSecurityToGroup, :v2c, @public_sec, @public_group},
  #     {:vacmSecurityToGroup, :v2c, @private_sec, @private_group},
  #     {:vacmSecurityToGroup, :v1, @public_sec, @public_group},
  #     {:vacmSecurityToGroup, :v1, @private_sec, @private_group},
  #     {:vacmAccess, @public_group, '', :v1, :noAuthNoPriv, :exact, 'internet', '', 'restricted'},
  #     {:vacmAccess, @public_group, '', :v2c, :noAuthNoPriv, :exact, 'internet', '', 'restricted'},
  #     {:vacmAccess, @public_group, '', :usm, :noAuthNoPriv, :exact, 'internet', '', 'restricted'},
  #     {:vacmAccess, @private_group, '', :v1, :noAuthNoPriv, :exact, 'restricted', 'restricted',
  #      'restricted'},
  #     {:vacmAccess, @private_group, '', :v2c, :noAuthNoPriv, :exact, 'restricted', 'restricted',
  #      'restricted'},
  #     {:vacmAccess, @private_group, '', :usm, :authNoPriv, :exact, 'restricted', 'restricted',
  #      'restricted'},
  #     {:vacmAccess, @private_group, '', :v1, :noAuthNoPriv, :exact, 'restricted', 'restricted',
  #      'restricted'},
  #     {:vacmAccess, @private_group, '', :v2c, :noAuthNoPriv, :exact, 'restricted', 'restricted',
  #      'restricted'},
  #     {:vacmAccess, @private_group, '', :usm, :authPriv, :exact, 'restricted', 'restricted',
  #      'restricted'},
  #     {:vacmViewTreeFamily, 'internet', [1, 3, 6, 1, 2, 1], :included, :null},
  #     {:vacmViewTreeFamily, 'restricted', [1, 3, 6, 1], :included, :null}
  #   ]

  #   s
  #   |> put_config(:vacm_conf, vacm_conf)
  # end

  # defp usm_conf(s) do
  #   usm_conf = [
  #     {'agent', '', 'publicSec', :zeroDotZero, :usmNoAuthProtocol, '', '', :usmNoPrivProtocol, '',
  #      '', '', '', ''},
  #     {'agent', 'admin', 'privateSec', :zeroDotZero, :usmHMACMD5AuthProtocol, '', '',
  #      :usmNoPrivProtocol, '', '', '',
  #      [69, 162, 150, 62, 179, 98, 234, 173, 133, 128, 124, 29, 219, 216, 70, 165], ''}
  #   ]

  #   s
  #   |> put_config(:usm_conf, usm_conf)
  # end

  # defp notify_conf(s) do
  #   notify_conf = [
  #     {'target1_v1', @notify_tag, :trap},
  #     {'target1_v2', @notify_tag, :trap},
  #     {'target1_v3', @notify_tag, :trap},
  #     {'target2_v1', @notify_tag, :trap},
  #     {'target2_v2', @notify_tag, :trap},
  #     {'target2_v3', @notify_tag, :trap},
  #     {'target3_v1', @notify_tag, :trap},
  #     {'target3_v2', @notify_tag, :trap},
  #     {'target3_v3', @notify_tag, :trap}
  #   ]

  #   s
  #   |> put_config(:notify_conf, notify_conf)
  # end

  # defp target_conf(s) do
  #   target_conf = []

  #   target_params_conf = [
  #     {'target_v1', :v1, :v1, @public_sec, :noAuthNoPriv},
  #     {'target_v2', :v2c, :v2c, @public_sec, :noAuthNoPriv},
  #     {'target_v3', :v3, :usm, @public_sec, :noAuthNoPriv}
  #   ]

  #   s
  #   |> put_config(:target_conf, target_conf)
  #   |> put_config(:target_params_conf, target_params_conf)
  # end

  defp commit(s) do
    :ok = Application.put_env(:snmp, :agent, Map.get(s, :agent_env))

    @configs
    |> Enum.reduce(s, fn {name, file}, acc ->
      case write_config(s.otp_app, file, Map.get(s, name)) do
        :ok -> acc
        {:error, error} -> error(acc, error)
      end
    end)
  end

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

  defp error(s, err), do: %{s | errors: s.errors ++ [err]}

  defp when_valid?(%{errors: []} = s, fun), do: fun.(s)

  defp when_valid?(s, _fun), do: s

  defp cast_address(a) when is_binary(a) do
    {:ok, addr} = :inet.parse_address(to_charlist(a))
    cast_address(addr)
  end

  defp cast_address({_, _, _, _} = a), do: {:transportDomainUdpIpv4, a}

  defp cast_address({_, _, _, _, _, _, _, _} = a), do: {:transportDomainUdpIpv6, a}

  defp mib_mod(s, name) do
    s.handler
    |> apply(:__agent__, [:mibs])
    |> Map.get(name)
  end
end
