defmodule Snmp.Ecto.Type.KeywordList do
  @moduledoc """
  Custom Ecto type for charlist backed keyword list

  See ENERGY-OBJECT-MIB EnergyObjectKeywordList
  """
  use Ecto.Type

  def type, do: :list

  def cast(v) when is_list(v) do
    kw = v |> Enum.map(&to_string/1)
    {:ok, kw}
  rescue
    _ -> :error
  end

  def cast(v) do
    kw =
      v
      |> to_string()
      |> String.split(",", trim: true)

    {:ok, kw}
  rescue
    _ -> :error
  end

  def load(v) do
    kw = v |> to_string() |> String.split(",")
    {:ok, kw}
  end

  def dump(v) do
    {:ok, v |> Enum.join(",")}
  end
end
