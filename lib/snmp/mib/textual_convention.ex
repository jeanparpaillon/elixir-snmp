defmodule Snmp.Mib.TextualConvention do
  @moduledoc false

  defmacro __using__(mapping: mapping) do
    quote do
      unquote(def_funs(mapping))
    end
  end

  defp def_funs(mapping) do
    mapping = Map.new(mapping)

    Enum.map(mapping, fn {name, value} ->
      quote do
        def value(unquote(name)), do: unquote(value)
      end
    end) ++
      Enum.map(mapping, fn {name, value} ->
        quote do
          def key(unquote(value)), do: unquote(name)
        end
      end) ++
      [
        quote do
          def mapping, do: unquote(Macro.escape(mapping))
        end
      ]
  end
end
