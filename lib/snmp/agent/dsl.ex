defmodule Snmp.Agent.DSL do
  @moduledoc """
  Defines macros for building SNMP Agent handler
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Snmp.Agent.DSL

      Module.register_attribute(__MODULE__, :mib, accumulate: true)
    end
  end

  @doc """
  Declares a MIB
  """
  defmacro mib(module) do
    quote do
      require unquote(module)
      @mib unquote(module)
    end
  end
end
