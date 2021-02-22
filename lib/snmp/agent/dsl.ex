defmodule Snmp.Agent.DSL do
  @moduledoc """
  Defines macros for building SNMP Agent handler
  """

  @doc false
  defmacro __using__(_opts) do
    Module.register_attribute(__CALLER__.module, :mib, accumulate: true)

    quote do
      import unquote(__MODULE__), only: :macros
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
