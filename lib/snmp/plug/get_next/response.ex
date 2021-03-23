defmodule Snmp.Plug.GetNext.Response do
  @moduledoc """
  Data structure for GetNext response
  """
  @derive {Jason.Encoder, only: [:errors, :objects, :next]}

  alias Snmp.Object
  alias Snmp.OID
  alias Snmp.Plug.GetNext

  defstruct errors: %{}, objects: %{}, next: nil

  @doc false
  def encode(%GetNext.Request{valid?: false} = req) do
    %__MODULE__{errors: req.errors}
  end

  def encode(objects) when is_list(objects) do
    {objects, next} =
      objects
      |> Enum.reduce({[], nil}, fn
        %Object{value: :endOfMibView} = o, {objects, _} ->
          {[o | objects], nil}

        %Object{oid: oid} = o, {objects, _} ->
          {[o | objects], oid}
      end)

    next =
      case next do
        nil -> nil
        oid -> OID.to_string(oid)
      end

    %__MODULE__{objects: Enum.reverse(objects), next: next}
  end
end
