defmodule Snmp.Instrumentation.Generic do
  @moduledoc """
  Generic instrumentation module using `:snmp_generic` functions
  """
  use Snmp.Instrumentation

  require Logger

  @default_opts [db: :mnesia]

  @impl Snmp.Instrumentation
  def build_extra(varname, opts) do
    opts = Keyword.merge(@default_opts, opts)
    db = Keyword.get(opts, :db)
    Keyword.merge(opts, namedb: {varname, db})
  end

  # Delegates :snmp_generic functions
  @snmp_generic_funs [
    get_index_types: 1,
    get_status_col: 2,
    get_table_info: 2,
    table_get_elements: 3,
    table_next: 2,
    table_row_exists: 2,
    table_set_elements: 3,
    variable_get: 1,
    variable_set: 2
  ]

  for {f, arity} <- @snmp_generic_funs do
    args = 1..arity |> Enum.map(&:"arg#{&1}") |> Enum.map(&{&1, [], Elixir}) |> Enum.to_list()
    defdelegate unquote(f)(unquote_splicing(args)), to: :snmp_generic
  end

  @doc false
  def variable_func(op, extra),
    do: :snmp_generic.variable_func(op, Keyword.get(extra, :namedb))

  def variable_func(op, val, extra),
    do: :snmp_generic.variable_func(op, val, Keyword.get(extra, :namedb))

  @doc false
  def table_func(:new, extra) do
    case Keyword.get(extra, :db) do
      :mnesia -> create_mnesia_table(extra)
      _ -> :ok
    end
  end

  def table_func(op, extra),
    do: :snmp_generic.table_func(op, Keyword.get(extra, :namedb))

  @doc false
  def table_func(op, row_index, cols, extra),
    do: :snmp_generic.table_func(op, row_index, cols, Keyword.get(extra, :namedb))

  defp create_mnesia_table(extra) do
    {table_name, _} = Keyword.get(extra, :namedb)
    caller = Keyword.fetch!(extra, :caller)
    table_info = apply(caller, :__mib__, [:table_infos])[table_name]

    table_attrs = [
      type: :ordered_set,
      snmp: [key: table_info.indices],
      attributes: table_info.columns |> Enum.map(&elem(&1, 3))
    ]

    table_name
    |> :mnesia.create_table(table_attrs)
    |> case do
      {:atomic, :ok} ->
        Logger.info("Created table #{table_name}")
        :ok

      {:aborted, {:already_exists, _}} ->
        Logger.info("Skip table #{table_name} (already exists)")
        :ok

      err ->
        Logger.error("Creating table #{table_name}: #{inspect(err)}")
        :ok
    end
  end
end
