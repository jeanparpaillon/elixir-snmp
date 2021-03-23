defmodule Snmp.Plug.GetNext.Request do
  @moduledoc """
  Data structure for GetNext request
  """
  use Snmp.Plug.Schema

  alias Snmp.OID

  defstruct errors: %{}, oid: nil, limit: 10, valid?: true

  @type t :: %__MODULE__{
          errors: map(),
          oid: Snmp.OID.t() | nil,
          limit: integer(),
          valid?: boolean()
        }

  @required [:oid]

  @doc """
  Parse connection parameters

  # Examples

    iex> parse(%{params: %{}})
    %Snmp.Plug.GetNext.Request{errors: %{oid: ["is required"]}, limit: 10, oid: nil, valid?: false}

    iex> parse(%{params: %{"oid" => "1.3.6"}})
    %Snmp.Plug.GetNext.Request{errors: %{}, limit: 10, oid: [1, 3, 6], valid?: true}

    iex> parse(%{params: %{"oid" => "1.3.6", "limit" => "32"}})
    %Snmp.Plug.GetNext.Request{errors: %{}, limit: 32, oid: [1, 3, 6], valid?: true}
  """
  @spec parse(Plug.Conn.t()) :: t()
  def parse(conn) do
    %__MODULE__{}
    |> cast_params(conn.params)
    |> validate_required(@required)
  end

  defp cast_params(s, params) do
    params
    |> Enum.reduce(s, fn
      {"oid", bin}, acc ->
        case OID.parse(bin) do
          {:ok, oid} -> Map.put(acc, :oid, oid)
          :error -> add_error(acc, :oid, "invalid: #{bin}")
        end

      {"limit", bin}, acc ->
        try do
          i = String.to_integer(bin)
          Map.put(acc, :limit, i)
        rescue
          ArgumentError ->
            add_error(acc, :limit, "must be an integer")
        end

      {_, _}, acc ->
        acc
    end)
  end
end
