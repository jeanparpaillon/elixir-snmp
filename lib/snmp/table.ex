defmodule Snmp.Table do
  @moduledoc """
  Behaviour for module implementing SNMP table instrumentation functions
  """
  require Record

  Record.defrecord(
    :table_info,
    Record.extract(:table_info, from_lib: "snmp/include/snmp_types.hrl")
  )

  @db :mnesia

  def last(table, ctx, default \\ 0) do
    :mnesia.activity(ctx, fn ->
      case :mnesia.last(table) do
        :"$end_of_table" -> default
        key -> key
      end
    end)
  end

  ###
  ### Instrumentation functions
  ###
  def new(table, cb) do
    ret =
      :mnesia.create_table(table,
        type: :ordered_set,
        snmp: [key: cb.table_infos(table, :indices)],
        attributes: cb.table_infos(table, :attributes)
      )

    case ret do
      {:atomic, :ok} ->
        ret

      err ->
        err
    end
  end

  def delete(table, _cb) do
    :mnesia.delete_table(table)
  end

  def get(table, rows, cols, _cb), do: :snmp_generic.table_func(:get, rows, cols, {table, @db})

  def get_next(table, rows, cols, _cb),
    do: :snmp_generic.table_func(:get_next, rows, cols, {table, @db})

  def is_set_ok(table, rows, cols, cb) do
    case :snmp_generic.table_func(:is_set_ok, rows, cols, {table, @db}) do
      {:noError, 0} ->
        Enum.reduce_while(cols, {:noError, 0}, fn {col, val}, acc ->
          case apply(cb, :"set_#{table}", [rows, col, val]) do
            :ok -> {:cont, acc}
            {:error, err} -> {:halt, {err, col}}
          end
        end)

      err ->
        err
    end
  end

  def undo(table, rows, cols, _cb), do: :snmp_generic.table_func(:undo, rows, cols, {table, @db})

  def set(table, rows, cols, _cb), do: :snmp_generic.table_func(:set, rows, cols, {table, @db})
end
