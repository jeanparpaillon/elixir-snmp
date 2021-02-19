defmodule Snmp.Agent.Handler do
  @moduledoc """
  Macros and functions for building SNMP agent handler
  """
  @mandatory_mibs ~w(STANDARD-MIB SNMP-FRAMEWORK-MIB)a

  defmacro __using__(opts) do
    app = Keyword.fetch!(opts, :otp_app)

    quote do
      use Snmp.Agent.DSL

      @otp_app unquote(app)

      @doc false
      def child_spec(_args), do: %{
        id: __MODULE__,
        start: {Snmp.Agent, :start_link, [__MODULE__]},
        type: :worker
      }

      @before_compile Snmp.Agent.Handler
    end
  end

  defmacro __before_compile__(env) do
    mib_mods = env.module |> Module.get_attribute(:mib, [])

    mib_mods
    |> Enum.reject(&Kernel.function_exported?(&1, :__mib__, 1))
    |> case do
      [] ->
        :ok

      invalid ->
        Mix.raise("The following modules do not implement a MIB: " <> Enum.join(invalid, " "))
    end

    mibs =
      mib_mods
      |> Enum.map(&{apply(&1, :__mib__, [:name]), &1})
      |> Enum.into(%{})

    (@mandatory_mibs -- Map.keys(mibs))
    |> case do
      [] ->
        :ok

      missing ->
        Mix.raise("Missing mandatory MIBs for SNMP agent: " <> Enum.join(missing, " "))
    end

    quote do
      def __agent__(:mibs), do: unquote(Macro.escape(mibs))
      def __agent__(:app), do: @otp_app
    end
  end
end
