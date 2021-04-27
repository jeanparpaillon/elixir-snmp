defmodule Snmp.Ecto.Type.UUID do
  @moduledoc false
  use Ecto.Type

  def type, do: :string

  def cast(v) when is_list(v) do
    v |> to_string() |> Ecto.UUID.cast()
  rescue
    ArgumentError ->
      :error
  end

  def cast(v), do: Ecto.UUID.cast(v)

  def load(v) do
    {:ok, v |> to_string()}
  end

  def dump(v) do
    {:ok, to_charlist(v)}
  end
end
