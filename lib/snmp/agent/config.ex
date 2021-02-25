defmodule Snmp.Agent.Config do
  @moduledoc """
  Handle agent configuration
  """
  require Snmp.Mib.Vacm

  alias Snmp.Mib.Community
  alias Snmp.Mib.UserBasedSm
  alias Snmp.Mib.Vacm
  alias Snmp.Transport

  @type t :: map()

  @dbdir "priv/snmp/agent/db"
  @confdir "priv/snmp/agent/conf"

  @default_mibs ~w(STANDARD-MIB SNMPv2 SNMP-FRAMEWORK-MIB SNMP-MPD-MIB)a

  @default_context ''

  @default_port 4000

  @default_transports ["127.0.0.1", "::1"]

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
    community_conf: "community.conf",
    vacm_conf: "vacm.conf",
    usm_conf: "usm.conf",
    notify_conf: "notify.conf",
    target_conf: "target_addr.conf",
    target_params_conf: "target_params.conf"
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
    |> (&(case ensure_conf_dir(&1.otp_app) do
            :ok -> &1
            {:error, err} -> error(&1, err)
          end)).()
    |> (&(case ensure_db_dir(&1.otp_app) do
            :ok -> &1
            {:error, err} -> error(&1, err)
          end)).()
    |> verbosity()
    |> when_valid?(&agent_env/1)
    |> when_valid?(&agent_conf/1)
    |> when_valid?(&context_conf/1)
    |> when_valid?(&community_conf/1)
    |> when_valid?(&vacm_conf/1)
    |> when_valid?(&usm_conf/1)
    |> when_valid?(&notify_conf/1)
    |> when_valid?(&target_conf/1)
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
        agent_verbosity: Map.fetch!(s, :verbosity),
        mibs: initial_mibs(s)
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
        [] -> Enum.map(@default_transports, &Transport.config/1)
        transports -> Enum.map(transports, &Transport.config/1)
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
    communities =
      s.handler
      |> apply(:__agent__, [:security_groups])
      |> Enum.reduce(MapSet.new(), fn
        {:vacmSecurityToGroup, :v1, sec_name, _}, acc -> MapSet.put(acc, sec_name)
        {:vacmSecurityToGroup, :v2c, sec_name, _}, acc -> MapSet.put(acc, sec_name)
        _, acc -> acc
      end)
      |> MapSet.to_list()
      |> Enum.map(&Community.new(name: &1, sec_name: &1))

    s
    |> Map.put(:community_conf, communities)
  end

  defp vacm_conf(s) do
    vacm_conf =
      apply(s.handler, :__agent__, [:accesses]) ++
        apply(s.handler, :__agent__, [:security_groups]) ++
        apply(s.handler, :__agent__, [:views])

    s
    |> Map.put(:vacm_conf, vacm_conf)
  end

  defp usm_conf(s) do
    engine_id =
      s
      |> mib_mod(:"SNMP-FRAMEWORK-MIB")
      |> apply(:__mib__, [:config])
      |> Keyword.get(:snmpEngineID)

    accesses =
      s.handler
      |> apply(:__agent__, [:accesses])
      |> Enum.reduce(%{}, fn access, acc ->
        name = :"#{Vacm.vacmAccess(access, :group_name)}"
        Map.put(acc, name, access)
      end)

    usm_conf =
      s.otp_app
      |> Application.get_env(s.handler, [])
      |> Keyword.get(:security, [])
      |> UserBasedSm.config(engine_id, accesses)

    s
    |> Map.put(:usm_conf, usm_conf)
  end

  defp notify_conf(s) do
    notify_conf = []

    s
    |> Map.put(:notify_conf, notify_conf)
  end

  defp target_conf(s) do
    target_conf = []
    target_params_conf = []

    s
    |> Map.put(:target_conf, target_conf)
    |> Map.put(:target_params_conf, target_params_conf)
  end

  defp commit(s) do
    IO.inspect(s, label: "CONF")
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

  defp mib_mod(s, name) do
    s.handler
    |> apply(:__agent__, [:mibs])
    |> Map.get(name)
  end

  defp initial_mibs(s) do
    mibs_paths = mibs_paths(s)

    s.handler
    |> apply(:__agent__, [:mibs])
    |> Enum.reject(&(elem(&1, 0) in @default_mibs))
    |> Enum.map(fn {name, _module} ->
      find_path(mibs_paths, "#{name}.bin")
    end)
    |> Enum.filter(& &1)
    |> Enum.map(&to_charlist/1)
  end

  defp find_path(paths, path) do
    paths
    |> Enum.map(&Path.join(&1, path))
    |> Enum.find(&File.exists?/1)
  end

  defp mibs_paths(s) do
    s.otp_app
    |> Application.get_env(s.handler, [])
    |> Keyword.get(:mibs_paths, [])
    |> Kernel.++([{s.otp_app, "priv/mibs"}, {:snmp, "priv/mibs"}])
    |> Enum.map(fn
      {app, dir} -> Application.app_dir(app, dir)
      dir when is_binary(dir) -> dir
    end)
  end
end
