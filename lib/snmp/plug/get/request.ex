defmodule Snmp.Plug.Get.Request do
  @moduledoc """
  Data structure for Get request
  """
  use Snmp.Plug.Schema

  alias Snmp.OID

  defstruct errors: %{}, oids: [], valid?: true

  @type t :: %__MODULE__{
          errors: map(),
          oids: [Snmp.OID.t()],
          valid?: boolean()
        }

  @doc """
  Parse connection parameters

  # Examples

    iex> parse(%{params: %{}})
    %Snmp.Plug.Get.Request{oids: [], errors: %{oids: ["can not be empty"]}, valid?: false}

    iex> parse(%{params: %{"1.3.6.1.2" => ""}})
    %Snmp.Plug.Get.Request{errors: %{}, oids: [{"1.3.6.1.2", [1, 3, 6, 1, 2]}], valid?: true}

    iex> parse(%{params: %{"0.top" => ""}})
    %Snmp.Plug.Get.Request{errors: %{oids: ["can not be empty", "invalid"]}, oids: [], valid?: false}
  """
  @spec parse(Plug.Conn.t()) :: t()
  def parse(conn) do
    %__MODULE__{}
    |> cast_params(conn.params)
    |> validate_non_empty([:oids])
  end

  defp cast_params(s, params) do
    params
    |> Map.keys()
    |> Enum.reduce_while({:ok, []}, fn bin, {:ok, acc} ->
      case OID.parse(bin) do
        {:ok, oid} -> {:cont, {:ok, [{bin, oid} | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      :error -> add_error(s, :oids, "invalid")
      {:ok, oids} -> %{s | oids: Enum.reverse(oids)}
    end
  end
end
