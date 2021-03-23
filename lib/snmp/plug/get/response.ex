defmodule Snmp.Plug.Get.Response do
  @moduledoc """
  Data structure for Get response
  """
  use Snmp.Plug.Schema

  @derive {Jason.Encoder, only: [:errors, :objects]}

  alias Snmp.Plug.Get

  defstruct errors: %{}, objects: %{}, valid?: true

  @doc false
  def encode(%Get.Request{valid?: false} = req) do
    %__MODULE__{errors: req.errors}
  end

  def encode(objects) when is_list(objects) do
    %__MODULE__{objects: Enum.into(objects, %{})}
  end

  def encode({:error, {reason, oid}}) do
    %__MODULE__{} |> add_error(:objects, "error #{oid}: #{reason}")
  end
end
