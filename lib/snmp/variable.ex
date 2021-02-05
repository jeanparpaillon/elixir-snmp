defmodule Snmp.Variable do
  @moduledoc """
  SNMP variable instrumentation functions
  """
  def new(var, cb), do: maybe_apply(cb, :'new_#{var}', [])

  def delete(var, cb), do: maybe_apply(cb, :'delete_#{var}', [])

  def get(var, cb), do: apply(cb, :'get_#{var}', [])

  def is_set_ok(var, value, cb), do: maybe_apply(cb, :'is_set_ok_#{var}', [value], fn -> :noError end)

  def undo(var, value, cb), do: maybe_apply(cb, :'undo_#{var}', [value], fn -> :noError end)

  def set(var, value, cb), do: apply(cb, :'set_#{var}', [value])

  ###
  ### Priv
  ###
  defp maybe_apply(m, f, a, default \\ fn -> :ok end) do
    if Module.defines?(m, {f, Enum.count(a)}, :def) do
      apply(m, f, a)
    else
      default.()
    end
  end
end
