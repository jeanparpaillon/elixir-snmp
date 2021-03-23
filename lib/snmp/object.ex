defmodule Snmp.Object do
  @moduledoc """
  Data structure for SNMP object
  """
  @derive {Jason.Encoder, only: [:oid, :name, :value]}

  alias Snmp.OID

  defstruct oid: nil, name: nil, value: nil

  @type t :: %__MODULE__{
          oid: OID.t() | nil,
          name: String.t() | nil,
          value: term() | nil
        }

  @doc """
  Returns object

  # Examples

    iex> new(%{oid: [1,2,3,4], value: :noSuchObject})
    %Snmp.Object{name: nil, oid: [1, 2, 3, 4], value: :noSuchObject}

    iex> new(%{oid: [1,2,3,4], value: 'This is a charlist'})
    %Snmp.Object{name: nil, oid: [1, 2, 3, 4], value: 'This is a charlist'}
  """
  @spec new(map) :: t()
  def new(params) do
    __MODULE__
    |> struct(Map.take(params, [:oid, :name]))
    |> cast_value(Map.get(params, :value))
  end

  defp cast_value(o, value) do
    %{o | value: value}
  end
end
