defmodule Snmp.Plug.GetTable.Response do
  @moduledoc """
  Data structure for GetTable response
  """
  use Snmp.Plug.Schema

  @derive {Jason.Encoder, only: [:errors, :rows]}

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
end
