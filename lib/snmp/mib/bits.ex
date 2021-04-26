defmodule Snmp.Mib.Bits do
  @moduledoc false

  defmacro __using__(kibbles: kibbles) do
    quote do
      use Ecto.Type
      use Bitwise

      @kibbles Enum.into(unquote(Macro.escape(kibbles)), %{})
      @kibbles_keys Map.keys(@kibbles)

      def type, do: :integer

      def embed_as, do: :dump

      def cast(value), do: normalize(value)

      def load(value) do
        v =
          @kibbles
          |> Enum.reduce([], fn {k, pos}, acc ->
            mask = 1 <<< (pos - 1)
            [{k, (value &&& mask) > 0} | acc]
          end)

        {:ok, v}
      end

      def dump(values) do
        case normalize(values) do
          {:ok, values} ->
            dumped =
              values
              |> Enum.map(fn {k, v} ->
                pos = Map.fetch!(@kibbles, k) - 1
                mask = 1 <<< pos
                {mask, v}
              end)
              |> Enum.reduce(0, fn
                {mask, true}, acc -> acc ||| mask
                {mask, false}, acc -> acc &&& ~~~mask
              end)

            {:ok, dumped}

          :error ->
            :error
        end
      rescue
        _ ->
          :error
      end

      defp normalize(value) when is_atom(value), do: normalize([value])

      defp normalize(values) when is_list(values) or is_map(values) do
        values
        |> Enum.reduce_while([], fn
          {k, v}, acc when is_atom(k) and is_boolean(v) ->
            if k in @kibbles_keys do
              {:cont, [{k, v} | acc]}
            else
              {:halt, :error}
            end

          k, acc when is_atom(k) ->
            if k in @kibbles_keys do
              {:cont, [{k, true} | acc]}
            else
              {:halt, :error}
            end
        end)
        |> case do
          :error -> :error
          kw -> {:ok, kw}
        end
      end
    end
  end
end
