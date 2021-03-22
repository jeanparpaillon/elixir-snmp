defmodule Snmp.OID do
  @moduledoc """
  OID handling functions
  """

  @type t :: [integer()]

  @doc """
  Returns OID from binary

  # Examples

    iex> parse("1.3.6.1.2")
    {:ok, [1, 3, 6, 1, 2]}

    iex> parse("")
    :error

    iex> parse("1.3.6..1")
    :error
  """
  @spec parse(binary()) :: {:ok, t()} | :error
  def parse(bin) when is_binary(bin),
    do: parse_oid(bin, [])

  defp parse_oid(params, acc) do
    case Integer.parse(params) do
      {i, <<?., rest::binary>>} -> parse_oid(rest, [i | acc])
      {i, <<>>} -> {:ok, Enum.reverse([i | acc])}
      _ -> :error
    end
  end

  @doc """
  Returns OID as string (dot notation)
  """
  @spec to_string(t()) :: String.t()
  def to_string(oid) when is_list(oid) do
    oid |> Enum.join(".")
  end
end
