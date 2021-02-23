defmodule Snmp.Agent.Error do
  @moduledoc """
  Exception raised when am agent definition is wrong
  """
  defexception message: "Invalid SNMP agent definition"

  def exception(message) do
    %__MODULE__{message: message}
  end
end
