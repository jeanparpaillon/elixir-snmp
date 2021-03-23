defmodule Snmp.Plug.Schema do
  @moduledoc """
  Facilities for request/responses schemas
  """
  defmacro __using__(_opts) do
    quote do
      import Snmp.Plug.Schema
    end
  end

  @doc false
  def add_error(%{errors: errors} = s, key, error) do
    errors = Map.put(errors, key, [error | Map.get(errors, key, [])])
    %{s | valid?: false, errors: errors}
  end

  @doc false
  def validate_required(s, required) do
    required
    |> Enum.reduce(s, fn req, acc ->
      case Map.get(acc, req) do
        nil -> add_error(acc, req, "is required")
        _ -> acc
      end
    end)
  end

  @doc false
  def validate_non_empty(s, required) do
    required
    |> Enum.reduce(s, fn req, acc ->
      case Map.get(s, req, []) do
        [] -> add_error(acc, req, "can not be empty")
        _ -> acc
      end
    end)
  end
end
