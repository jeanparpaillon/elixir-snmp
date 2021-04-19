defmodule Snmp.Ecto.Type.TruthValue do
  @moduledoc """
  Custom Ecto type for SNMPv2-TC 'TruthValue'
  """
  use Ecto.Type

  def type, do: :integer

  def cast(v) when is_boolean(v), do: {:ok, v}

  def cast(1), do: {:ok, true}

  def cast(2), do: {:ok, false}

  def cast(_), do: :error

  def load(1), do: true

  def load(2), do: false

  def load(_), do: :error

  def dump(true), do: {:ok, 1}

  def dump(false), do: {:ok, false}

  def dump(_), do: :error
end
