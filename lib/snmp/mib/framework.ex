defmodule Snmp.Mib.Framework do
  @moduledoc """
  Helper for implementing SNMP-FRAMEWORK-MIB
  """
  alias Snmp.Agent

  defmacro __using__(opts) do
    app = Keyword.fetch!(opts, :otp_app)
    agent = Keyword.fetch!(opts, :agent)
    conf = Keyword.fetch!(opts, :conf)

    quote do
      conf =
        unquote(conf)
        |> Enum.map(fn
          {k, v} when is_binary(v) -> {k, to_charlist(v)}
          {k, v} -> {k, v}
        end)

      ([:snmpEngineID, :snmpEngineMaxMessageSize] -- Keyword.keys(conf))
      |> case do
        [] ->
          :ok

        missing ->
          err = "Missing mandatory variables for FRAMEWORK-MIB:" <> Enum.join(missing, " ")
          Mix.raise(err)
      end

      Agent.Config.write_config({unquote(app), unquote(agent)}, "agent.conf", conf, true)

      @mib_name :"SNMP-FRAMEWORK-MIB"
      @mib_extra config: conf

      @before_compile Snmp.Mib
    end
  end
end
