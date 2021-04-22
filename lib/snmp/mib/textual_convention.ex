defmodule Snmp.Mib.TextualConvention do
  @moduledoc false

  defmacro __using__(mapping: mapping) do
    mapping = Map.new(mapping)

    quote do
      use Ecto.Type

      unquote(def_funs(mapping))
      unquote(def_ecto_funs(mapping))
    end
  end

  defp def_funs(mapping) do
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

  defp def_ecto_funs(mapping) do
    quote bind_quoted: [mapping: Macro.escape(mapping)] do
      def type, do: :integer

      def embed_as, do: :dump

      for {k, v} <- mapping do
        k_str = to_string(k)

        def cast(unquote(k)), do: {:ok, unquote(k)}

        def cast(unquote(k_str)), do: {:ok, unquote(k)}

        def cast(unquote(v)), do: {:ok, unquote(k)}
      end

      def cast(_), do: :error

      for {k, v} <- mapping do
        def load(unquote(v)), do: {:ok, unquote(k)}
      end

      def load(_), do: :error

      for {k, v} <- mapping do
        def dump(unquote(k)), do: {:ok, unquote(v)}
      end

      def dump(_), do: :error
    end
  end
end
