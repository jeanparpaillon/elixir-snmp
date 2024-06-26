defmodule Snmp.Ecto.Type.OID do
  @moduledoc false
  use Ecto.Type

  def type, do: {:array, :integer}

  def cast(value) when is_list(value) do
    if Enum.all?(value, &is_integer/1) do
      {:ok, value}
    else
      :error
    end
  end

  def cast({mib, name}) when is_atom(mib) and is_atom(name) do
    {:ok, mib.__mib__(:oids)[name]}
  rescue
    _ -> :error
  end

  def cast(value) when is_atom(value) do
    value |> to_string() |> Snmp.OID.parse()
  end

  def cast(value) when is_binary(value) do
    value |> Snmp.OID.parse()
  end

  def cast(_), do: :error

  def load(value), do: {:ok, value}

  def dump(value) when is_list(value) do
    {:ok, value}
  end

  def dump(_), do: :error
end
