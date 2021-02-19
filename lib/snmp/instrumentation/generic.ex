defmodule Snmp.Instrumentation.Generic do
  @moduledoc """
  Generic instrumentation module using `:snmp_generic` functions
  """
  use Snmp.Instrumentation

  @impl Snmp.Instrumentation
  def build_extra(varname, opts), do: {varname, opts}

  # Delegates :snmp_generic functions
  @snmp_generic_funs [
    get_index_types: 1,
    get_status_col: 2,
    get_table_info: 2,
    table_func: 2,
    table_func: 4,
    table_get_elements: 3,
    table_next: 2,
    table_row_exists: 2,
    table_set_elements: 3,
    variable_func: 2,
    variable_func: 3,
    variable_get: 1,
    variable_set: 2
  ]

  for {f, arity} <- @snmp_generic_funs do
    args = 1..arity |> Enum.map(&:"arg#{&1}") |> Enum.map(&{&1, [], Elixir}) |> Enum.to_list()
    defdelegate unquote(f)(unquote_splicing(args)), to: :snmp_generic
  end
end
