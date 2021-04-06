defmodule Snmp.Plug.GetTable.Request do
  @moduledoc """
  Data structure for GetTable request
  """
  use Snmp.Plug.Schema

  defstruct errors: %{}, table_name: nil, start: [], limit: 10, valid?: true

  @type t :: %__MODULE__{
          errors: map(),
          table_name: atom() | nil,
          start: [integer()],
          limit: integer(),
          valid?: boolean()
        }

  @required [:table_name]

  @doc """
  Parse connection parameters
  """
  @spec parse(Plug.Conn.t()) :: t()
  def parse(conn) do
    %__MODULE__{}
    |> cast_table_name(conn.path_info)
    |> cast_params(conn.params)
    |> validate_required(@required)
  end

  defp cast_table_name(s, ["table", bin]) do
    table_name = String.to_existing_atom(bin)

    case :snmpa.name_to_oid(table_name) do
      {:value, _} -> Map.put(s, :table_name, table_name)
      false -> add_error(s, :table_id, "invalid table name: #{bin}")
    end
  rescue
    ArgumentError ->
      add_error(s, :table_id, "invalid table name: #{bin}")
  end

  defp cast_table_name(s, _), do: s

  defp cast_params(s, params) do
    params
    |> Enum.reduce(s, fn
      {"start", bin}, acc ->
        try do
          ids = String.split(bin, ",")
          Map.put(acc, :start, Enum.map(ids, &String.to_integer/1))
        rescue
          ArgumentError ->
            add_error(acc, :start, "invalid index")
        end

      {"limit", bin}, acc ->
        try do
          i = String.to_integer(bin)
          Map.put(acc, :limit, i)
        rescue
          ArgumentError ->
            add_error(acc, :limit, "must be an integer")
        end

      {_, _}, acc ->
        acc
    end)
  end
end
