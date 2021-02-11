defmodule Snmp.Mib.Framework do
  @moduledoc """
  Describes callbacks for implementing SNMP-FRAMEWORK-MIB
  """
  alias Snmp.Instrumentation

  @callback snmpEngineID(Instrumentation.op_read_only()) :: Instrumentation.get_ret()

  @callback snmpEngineBoots(Instrumentation.op_read_only()) :: Instrumentation.get_ret()

  @callback snmpEngineTime(Instrumentation.op_read_only()) :: Instrumentation.get_ret()

  @callback snmpEngineMaxMessageSize(Instrumentation.op_read_only()) :: Instrumentation.get_ret()

  @optional_callbacks snmpEngineBoots: 1, snmpEngineTime: 1
end
