defmodule Snmp.Instrumentation.Generic do
  @moduledoc """
  Generic instrumentation module using `:snmp_generic` functions
  """
  use Snmp.Instrumentation

  alias Snmp.Instrumentation

  @impl Instrumentation
  def init(nil), do: :volatile

  def init(db), do: db

  @impl Instrumentation
  def new(varname, db), do: :snmp_generic.variable_func(:new, {varname, db})

  @impl Instrumentation
  def new_table(table, db), do: :snmp_generic.table_func(:new, {table, db})

  @impl Instrumentation
  def delete(varname, db), do: :snmp_generic.variable_func(:delete, {varname, db})

  @impl Instrumentation
  def delete_table(table, db), do: :snmp_generic.table_func(:delete, {table, db})

  @impl Instrumentation
  def get(varname, db), do: :snmp_generic.variable_func(:get, {varname, db})

  @impl Instrumentation
  def get(table, row_index, cols, db),
    do: :snmp_generic.table_func(:get, row_index, cols, {table, db})

  @impl Instrumentation
  def get_next(varname, row_index, cols, db),
    do: :snmp_generic.table_func(:get_next, row_index, cols, {varname, db})

  @impl Instrumentation
  def is_set_ok(varname, val, db), do: :snmp_generic.variable_func(:is_set_ok, val, {varname, db})

  @impl Instrumentation
  def is_set_ok(table, row_index, cols, db),
    do: :snmp_generic.table_func(:is_set_ok, row_index, cols, {table, db})

  @impl Instrumentation
  def set(varname, val, db), do: :snmp_generic.variable_func(:set, val, {varname, db})

  @impl Instrumentation
  def set(table, row_index, cols, db),
    do: :snmp_generic.table_func(:set, row_index, cols, {table, db})

  @impl Instrumentation
  def undo(varname, val, db), do: :snmp_generic.variable_func(:undo, val, {varname, db})

  @impl Instrumentation
  def undo(table, row_index, cols, db),
    do: :snmp_generic.table_func(:undo, row_index, cols, {table, db})
end
