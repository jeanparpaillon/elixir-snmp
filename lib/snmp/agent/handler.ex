defmodule Snmp.Agent.Handler do
  @moduledoc false
  alias Snmp.Object

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
      defdelegate oid_to_name(oid), to: Snmp.Agent.Handler

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
  @spec stream(:snmp.oid()) :: Enumerable.t()
  def stream(oid) do
    Stream.resource(stream_init(oid), &stream_cont/1, &stream_end/1)
  end

  @doc """
  Return MIB objects
  """
  @spec get([:snmp.oid()], String.t()) :: [Object.t()] | {:error, {atom(), :snmp.oid()}}
  def get(oids, ctx \\ "") do
    :snmp_master_agent
    |> :snmpa.get(oids, ctx)
    |> case do
      {:error, _} = err ->
        err

      data ->
        [oids, data]
        |> Enum.zip()
        |> Enum.map(&to_object/1)
    end
  end

  @doc """
  OID to name
  """
  def oid_to_name(oid) do
    oid |> Enum.reverse() |> oid_to_name([]) |> Enum.join(".")
  end

  ###
  ### Priv
  ###
  defp oid_to_name([], acc), do: acc

  defp oid_to_name(r_oid, acc) do
    case :snmpa.oid_to_name(Enum.reverse(r_oid)) do
      false ->
        [suffix | r_oid] = r_oid
        oid_to_name(r_oid, [suffix | acc])

      {:value, name} ->
        [name | acc]
    end
  end

  ###
  ### Priv
  ###
  defp stream_init(oid), do: fn -> [oid] end

  defp stream_cont(:endOfMibView), do: {:halt, []}

  defp stream_cont(oids) do
    case :snmpa.get_next(:snmp_master_agent, oids) do
      {:error, _reason} -> {:halt, []}
      [] -> {:halt, []}
      [{oid, :endOfMibView}] -> {[to_object(oid, :endOfMibView)], :endOfMibView}
      [{oid, value}] -> {[to_object(oid, value)], [oid]}
    end
  end

  defp stream_end(_oid), do: :ok

  defp to_object({oid, value}), do: to_object(oid, value)

  defp to_object(oid, value) do
    me = :snmpa.me_of(oid)
    Object.new(%{oid: oid, name: oid_to_name(oid), value: cast_value(me, value)})
  end

  defp cast_value(
         {:ok,
          {:me, _, _, _, {:asn1_type, :"OCTET STRING", _, _, _, _, _, _, _}, _, _, _, _, _, _}},
         value
       ) do
    to_string(value)
  end

  defp cast_value(_, value), do: value
end
