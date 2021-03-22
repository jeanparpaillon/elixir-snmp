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

      defdelegate get(oid_or_oids), to: Snmp.Agent.Handler
      defdelegate get(oid_or_oids, ctx), to: Snmp.Agent.Handler
      defdelegate stream(oid), to: Snmp.Agent.Handler

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

  @doc """
  Returns MIB tree as stream
  """
  @spec stream(:snmp.oid()) :: Enum.t()
  def stream(oid) do
    Stream.resource(
      fn -> [oid] end,
      fn oids ->
        case :snmpa.get_next(:snmp_master_agent, oids) do
          {:error, reason} -> {:halt, {:error, reason}}
          [] -> {:halt, :ok}
          [{oid, :endOfMibView}] -> {:halt, oid}
          [{oid, value}] -> {[{oid, value}], [oid]}
        end
      end,
      fn _oid -> :ok end
    )
  end

  @doc """
  Return MIB objects
  """
  @spec get([:snmp.oid()], String.t()) :: [term()] | {:error, {atom(), :snmp.oid()}}
  def get(oids, ctx \\ "") do
    :snmpa.get(:snmp_master_agent, oids, ctx)
  end

  @doc """
  Resolve OID into dot separated names
  """
  @spec oid_to_dot(:snmp.oid()) :: String.t()
  def oid_to_dot(oid) when is_list(oid) do
    oid
    |> oid_to_names([])
    |> Enum.join(".")
  end

  ###
  ### Priv
  ###
  defp oid_to_names([], acc), do: acc

  defp oid_to_names([1, 3, 6, 1, 2], acc), do: acc

  defp oid_to_names(oid, acc) do
    r_oid = Enum.reverse(oid)

    name =
      case :snmpa.oid_to_name(oid) do
        false -> "#{hd(r_oid)}"
        {:value, name} -> name
      end

    oid = r_oid |> tl() |> Enum.reverse()
    oid_to_names(oid, [name | acc])
  end
end
