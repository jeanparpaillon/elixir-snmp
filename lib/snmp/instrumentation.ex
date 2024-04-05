defmodule Snmp.Instrumentation do
  @moduledoc """
  Describes behaviour for module implementing MIB instrumentation functions
  """
  require Record

  Record.defrecord(:me, Record.extract(:me, from_lib: "snmp/include/snmp_types.hrl"))

  @callback build_extra(varname :: atom(), any()) :: any()

  @type row_index :: [integer()]
  @type col() :: integer()
  @type oid() :: [integer()]
  @type varname :: atom()

  @type gen_err :: :genErr
  @type get_err :: {:noValue, :noSuchObject | :noSuchInstance}
  @type get_ret :: {:value, term()} | get_err()
  @type is_set_ok_err ::
          :noAccess | :noCreation | :inconsistentValue | :resourceUnavailable | :inconsistentName
  @type is_set_ok_ret :: :noError | is_set_ok_err()
  @type undo_err :: :undoFailed
  @type set_err :: :commitFailed | :undoFailed

  defmacro __using__(_opts) do
    quote do
      @behaviour Snmp.Instrumentation

      @impl Snmp.Instrumentation
      def build_extra(varname, opts), do: {varname, opts}

      defoverridable build_extra: 2
    end
  end

  defmacro __before_compile__(env) do
    variables = env.module |> Module.get_attribute(:variable)
    tables = env.module |> Module.get_attribute(:table)

    env.module
    |> Module.get_attribute(:instrumentation)
    |> gen_instrumentation(variables, tables, env)
  end

  @doc false
  def __after_compile__(env, _bytecode) do
    missing_varfuns =
      env.module.__mib__(:varfuns)
      |> Enum.reject(&Module.defines?(env.module, &1, :def))

    missing_tablefuns =
      env.module.__mib__(:tablefuns)
      |> Enum.reject(&Module.defines?(env.module, &1, :def))

    case missing_varfuns ++ missing_tablefuns do
      [] ->
        :ok

      missing ->
        mib_name = env.module.__mib__(:name)

        err =
          """
          Following instrumentation functions are missing for module #{env.module} (mib #{mib_name}):
          """ <> (missing |> Enum.map_join("\n", &"\t* #{elem(&1, 0)}: #{elem(&1, 1)}"))

        Mix.shell().error(err)
        Mix.raise("Error compiling #{env.module}")
    end
  end

  defp gen_instrumentation(_instr, [], [], _env), do: []

  defp gen_instrumentation({mod, opts}, varfuns, tablefuns, env) do
    if mod == env.module do
      [gen_impl()]
    else
      [gen_instrumentation_init(mod, opts)] ++
        Enum.map(varfuns, &gen_varfun(&1, env)) ++
        Enum.map(tablefuns, &gen_tablefun(&1, env))
    end
  end

  defp gen_impl do
    quote do
      @after_compile Snmp.Instrumentation
    end
  end

  defp gen_instrumentation_init(mod, opts) do
    quote do
      require unquote(mod)
      @instr_mod unquote(mod)
      @instr_opts unquote(opts)
    end
  end

  defp gen_varfun({varname, _}, env) do
    []
    |> if_not_defined(
      {env.module, {varname, 1}},
      quote bind_quoted: [varname: varname] do
        extra = @instr_mod.build_extra(varname, @instr_opts)

        def unquote(Macro.escape(varname))(op),
          do: @instr_mod.variable_func(op, unquote(extra))
      end
    )
    |> if_not_defined(
      {env.module, {varname, 2}},
      quote bind_quoted: [varname: varname] do
        extra = @instr_mod.build_extra(varname, @instr_opts)

        def unquote(Macro.escape(varname))(op, val),
          do: apply(@instr_mod, op, [val, unquote(extra)])
      end
    )
  end

  defp gen_tablefun({tablename, _}, env) do
    []
    |> if_not_defined(
      {env.module, {tablename, 1}},
      quote bind_quoted: [tablename: tablename] do
        extra = @instr_mod.build_extra(tablename, @instr_opts)

        def unquote(Macro.escape(tablename))(op),
          do: @instr_mod.table_func(op, unquote(extra))
      end
    )
    |> if_not_defined(
      {env.module, {tablename, 3}},
      quote bind_quoted: [tablename: tablename] do
        extra = @instr_mod.build_extra(tablename, @instr_opts)

        def unquote(Macro.escape(tablename))(op, row_index, cols),
          do: @instr_mod.table_func(op, row_index, cols, unquote(extra))
      end
    )
  end

  defp if_not_defined(acc, {mod, fun}, ast) do
    if Module.defines?(mod, fun) do
      acc
    else
      acc ++ [ast]
    end
  end
end
