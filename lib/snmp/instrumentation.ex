defmodule Snmp.Instrumentation do
  @moduledoc """
  Describes behaviour for module implementing MIB instrumentation functions
  """
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

  @callback new(varname()) :: :ok

  @callback delete(varname()) :: :ok

  @callback get(varname()) :: get_ret() | gen_err()

  @callback get(varname(), row_index(), [col()]) :: [get_ret()] | get_err() | gen_err()

  @callback get_next(varname(), row_index(), [col()]) ::
              [{oid(), term()} | :endOfTable] | {:genErr, integer()}

  @callback is_set_ok(varname(), term()) :: is_set_ok_ret() | gen_err()

  @callback is_set_ok(varname(), row_index(), [{col(), term()}]) ::
              {:noError, 0} | {is_set_ok_err(), col()}

  @callback undo(varname(), term()) :: :noError | undo_err() | gen_err()

  @callback undo(varname(), row_index(), [{col(), term()}]) :: {:noError, 0} | {undo_err(), col()}

  @callback set(varname(), term()) :: :noError | set_err() | gen_err()

  @callback set(varname(), row_index(), [{col(), term()}]) :: {:noError, 0} | {set_err(), col()}

  @optional_callbacks new: 1, delete: 1, is_set_ok: 2, is_set_ok: 3, undo: 2, undo: 3

  defmacro __before_compile__(env) do
    varfuns = env.module |> Module.get_attribute(:varfun)
    tablefuns = env.module |> Module.get_attribute(:tablefun)

    mod = Module.get_attribute(env.module, :instrumentation)
    instrumentation? = mod == env.module and (varfuns != [] or tablefuns != [])

    if instrumentation? do
      [gen_instrumentation()] ++
        Enum.map(varfuns, &gen_varfun(&1, mod)) ++
        Enum.map(tablefuns, &gen_tablefun(&1, mod))
    else
      []
    end
  end

  defp gen_varfun(varname, mod) do
    quote do
      def unquote(varname)(op) when op in [:new, :delete, :get],
        do: apply(unquote(mod), op, [unquote(varname)])

      def unquote(varname)(op, val) when op in [:is_set_ok, :undo, :set],
        do: apply(unquote(mod), op, [unquote(varname), val])
    end
  end

  defp gen_tablefun(varname, mod) do
    quote do
      def unquote(varname)(op) when op in [:new, :delete],
        do: apply(unquote(mod), op, [unquote(varname)])

      def unquote(varname)(op, row_index, cols)
          when op in [:get, :get_next, :is_set_ok, :undo, :set],
          do: apply(unquote(mod), op, [unquote(varname), row_index, cols])
    end
  end

  defp gen_instrumentation do
    quote do
      @behaviour Snmp.Instrumentation

      @doc false
      def new(_), do: :ok

      @doc false
      def delete(_), do: :ok

      @doc false
      def is_set_ok(_, _), do: :noError

      @doc false
      def is_set_ok(_, _, _), do: {:noError, 0}

      @doc false
      def undo(_, _), do: :noError

      @doc false
      def undo(_, _, _), do: :noError

      defoverridable new: 1, delete: 1, is_set_ok: 2, is_set_ok: 3, undo: 2, undo: 3
    end
  end
end
