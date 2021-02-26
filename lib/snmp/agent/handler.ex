defmodule Snmp.Agent.Handler do
  @moduledoc false
  @mandatory_mibs ~w(STANDARD-MIB SNMP-FRAMEWORK-MIB)a

  defmacro __using__(opts) do
    app = Keyword.fetch!(opts, :otp_app)

    quote do
      use Snmp.Agent.DSL

      @otp_app unquote(app)

      @doc false
      def child_spec(_args),
        do: %{
          id: __MODULE__,
          start: {Snmp.Agent, :start_link, [__MODULE__]},
          type: :worker
        }

      @before_compile Snmp.Agent.Handler
    end
  end

  defmacro __before_compile__(env) do
    mibs =
      env.module
      |> Module.get_attribute(:mib, [])
      |> Enum.map(fn [module: mod] ->
        apply(mod, :__mib__, [:name])
      end)

    (@mandatory_mibs -- mibs)
    |> case do
      [] ->
        :ok

      missing ->
        Mix.raise("Missing mandatory MIBs for SNMP agent: " <> Enum.join(missing, " "))
    end
  end
end
