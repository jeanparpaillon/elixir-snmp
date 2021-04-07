defmodule Snmp.Plug.GetTable.Response do
  @moduledoc """
  Data structure for GetTable response
  """
  use Snmp.Plug.Schema

  alias Snmp.Plug.GetTable

  defstruct errors: %{}, rows: [], valid?: true

  @doc false
  def encode(%GetTable.Request{valid?: false} = req) do
    %__MODULE__{errors: req.errors}
  end

  def encode(rows) when is_list(rows) do
    %__MODULE__{rows: rows}
  end

  def encode({:error, {reason, oid}}) do
    %__MODULE__{} |> add_error(:objects, "error #{oid}: #{reason}")
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      {rows, next} =
        value.rows
        |> Enum.reduce({[], :endOfTable}, fn {row, next}, {rows, _} ->
          {[row | rows], next}
        end)
        |> case do
          {rows, :endOfTable} ->
            {Enum.reverse(rows), ""}

          {rows, {:ok, next}} ->
            {Enum.reverse(rows), next |> Enum.map(&"#{&1}") |> Enum.join(",")}
        end

      %{errors: value.errors, rows: rows, next: next}
      |> Jason.Encode.map(opts)
    end
  end
end
