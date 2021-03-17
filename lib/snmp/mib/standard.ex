defmodule Snmp.Mib.Standard do
  @moduledoc """
  Helper for implementing STANDARD-MIB
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

      ([:sysObjectID, :sysServices, :snmpEnableAuthenTraps] -- Keyword.keys(conf))
      |> case do
        [] ->
          :ok

        missing ->
          err = "Missing mandatory variables for STANDARD-MIB:" <> Enum.join(missing, " ")
          Mix.raise(err)
      end

      @mib_name :"STANDARD-MIB"
      @mib_extra config: conf

      @before_compile Snmp.Mib
    end
  end
end
