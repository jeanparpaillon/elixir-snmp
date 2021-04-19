defmodule Snmp.ASN1.TableEntry do
  @moduledoc """
  Use this module to build table entries records
  """

  defmacro __using__({table_name, infos}) do
    %{indices: _indices, columns: columns, infos: infos} = infos

    quote do
      @table_name unquote(table_name)
      @columns unquote(Macro.escape(columns))
      @infos unquote(Macro.escape(infos))

      @before_compile {unquote(__MODULE__), :__gen_records__}
      @before_compile {unquote(__MODULE__), :__gen_casters__}
    end
  end

  defmacro __gen_records__(_env) do
    quote unquote: false do
      require Record
      alias Snmp.ASN1.Types

      defvals = elem(@infos, 2)

      # By convention (?) SNMP tables' index is first field
      # Do not set default value for index column
      [{index, _} | attributes] =
        @columns
        |> Enum.map(
          &{elem(&1, 3), Keyword.get_lazy(defvals, elem(&1, 3), fn -> Types.default(&1) end)}
        )

      Record.defrecord(:entry, @table_name, [{index, nil} | attributes])

      Record.defrecord(:ms, @table_name, Enum.map(@columns, &{elem(&1, 3), :_}))
    end
  end

  defmacro __gen_casters__(_env) do
    quote unquote: false do
      @doc """
      Returns new record
      """
      def new, do: entry()

      @doc false
      def new(nil), do: entry()

      def new(e = entry()), do: e

      @doc """
           Cast parameters into #{@table_name} type

           # Parameters

           """ <> Enum.join(Enum.map(attributes, &"* `#{elem(&1, 0)}`"), "\n")
      def cast(entry \\ new(), params) do
        Enum.reduce(params, new(entry), &__cast_param__/2)
      end

      for {:me, _oid, _entrytype, col_name, _asn1_type, _access, _mfa, _imported, _assoc_list,
           _description, _units} = me <- @columns do
        defp __cast_param__({unquote(col_name), nil}, acc), do: acc

        defp __cast_param__({unquote(col_name), value}, acc) do
          entry(acc, [{unquote(col_name), Types.cast(value, unquote(Macro.escape(me)))}])
        end
      end
    end
  end
end
