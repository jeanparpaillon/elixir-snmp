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
  def parse(bin) when is_binary(bin) do
    case String.split(bin, "::", parts: 2, trim: true) do
      [_mibname, oid] -> parse_oid(oid, [])
      [oid] -> parse_oid(oid, [])
    end
  end

  @doc """
  Returns OID as string (dot notation)
  """
  @spec to_string(t()) :: String.t()
  def to_string(oid) when is_list(oid) do
    oid |> Enum.join(".")
  end

  ###
  ### Priv
  ###
  defp parse_oid(bin, acc) do
    case Integer.parse(bin) do
      {i, <<?., rest::binary>>} -> parse_oid(rest, [i | acc])
      {i, <<>>} -> {:ok, Enum.reverse([i | acc])}
      :error -> parse_oname(bin, acc)
    end
  end

  defp parse_oname(bin, []) do
    [prefix | rest] = String.split(bin, ".", parts: 2)

    prefix
    |> String.to_existing_atom()
    |> :snmpa.name_to_oid()
    |> case do
      {:value, oid} ->
        case rest do
          [] -> {:ok, oid}
          [rest] -> parse_oid(rest, Enum.reverse(oid))
        end

      false ->
        :error
    end
  rescue
    ArgumentError ->
      :error
  end

  # Object name is acceptable only as prefix
  defp parse_oname(_, _acc), do: :error
end
