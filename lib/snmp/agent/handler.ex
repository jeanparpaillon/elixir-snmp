defmodule Snmp.Agent.Handler do
  @moduledoc """
  Defines callbacks for Snmp Agent handler
  """
  @callback db_dir() :: Path.t()
  @callback conf_dir() :: Path.t()

  @doc "See `http://erlang.org/doc/man/SNMP_app.html`"
  @callback agent_env() :: Keyword.t()
  @callback net_if_env() :: Keyword.t()

  @callback net_conf() ::
              :inet.port_number()
              | {:inet.ip_address() | [:inet.ip_address()], :inet.port_number()}

  @doc """
  Returns module implementing SNMP-FRAMEWORK-MIB
  """
  @callback framework_mib() :: module()

  @doc """
  Returns module implementing STANDARD-MIB
  """
  @callback standard_mib() :: module()

  @callback contexts() :: [String.Chars.t()]

  defmacro __using__(opts) do
    app = Keyword.fetch!(opts, :otp_app)
    standard_mib = Keyword.fetch!(opts, :standard)
    framework_mib = Keyword.fetch!(opts, :framework)

    quote do
      @behaviour Snmp.Agent.Handler

      @otp_app unquote(app)

      def db_dir, do: Application.app_dir(@otp_app, "priv/snmp/agent/db")

      def conf_dir, do: Application.app_dir(@otp_app, "priv/snmp/agent/conf")

      def agent_env, do: Application.get_env(@otp_app, :snmp_agent, [])

      def net_if_env, do: agent_env() |> Keyword.get(:net_if, [])

      def net_conf, do: Application.get_env(@otp_app, :snmp_net, 161)

      def framework_mib, do: unquote(framework_mib)

      def standard_mib, do: unquote(standard_mib)

      def contexts, do: []

      defoverridable db_dir: 0, conf_dir: 0, agent_env: 0, contexts: 0
    end
  end
end
