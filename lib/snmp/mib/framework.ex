defmodule Snmp.Mib.Framework do
  @moduledoc """
  Describes callbacks for implementing SNMP-FRAMEWORK-MIB
  """
  alias Snmp.Instrumentation

  @callback snmpEngineID(atom()) :: Instrumentation.get_ret()

  @callback snmpEngineBoots(atom()) :: Instrumentation.get_ret()

  @callback snmpEngineTime(atom()) :: Instrumentation.get_ret()

  @callback snmpEngineMaxMessageSize(atom()) :: Instrumentation.get_ret()

  @optional_callbacks snmpEngineBoots: 1, snmpEngineTime: 1
end
