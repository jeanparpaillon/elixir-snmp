defmodule Snmp.Schema do
  @moduledoc """
  Ecto schema for MIB tables
  """
  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      @primary_key false
    end
  end
end
