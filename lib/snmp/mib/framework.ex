defmodule Snmp.Mib.Framework do
  @moduledoc """
  Helper for implementing SNMP-FRAMEWORK-MIB
  """
  defmacro __using__(opts) do
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

      @mib_name :"SNMP-FRAMEWORK-MIB"
      @mib_extra config: conf

      @before_compile Snmp.Mib
    end
  end
end
