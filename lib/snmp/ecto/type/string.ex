defmodule Snmp.Ecto.Type.String do
  @moduledoc """
  Custom type for SNMP strings (stored as charlist)
  """
  use Ecto.Type

  def type, do: :string

  def cast(v) when is_binary(v), do: {:ok, v}

  def cast(v) when is_list(v) do
    {:ok, to_string(v)}
  rescue
    ArgumentError ->
      :error
  end

  def cast(_), do: :error

  def load(v) do
    {:ok, to_string(v)}
  rescue
    ArgumentError ->
      :error
  end

  def dump(v), do: {:ok, to_charlist(v)}
end
