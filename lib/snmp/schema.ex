defmodule Snmp.Schema do
  @moduledoc """
  Ecto schema for MIB tables
  """
  defmacro __using__(opts) do
    field_prefix_mapper =
      case Keyword.get(opts, :field_prefix) do
        nil ->
          []

        prefix ->
          [
            quote do
              @field_source_mapper Snmp.Schema.prefix_field_mapper(unquote(prefix))
            end
          ]
      end

    [
      quote do
        use Ecto.Schema

        import Ecto.Changeset

        @primary_key false
      end
    ] ++ field_prefix_mapper
  end

  @doc false
  def prefix_field_mapper(prefix) do
    fn field ->
      ("#{prefix}" <> (field |> to_string() |> Macro.camelize())) |> String.to_atom()
    end
  end
end
