defmodule Snmp.ASN1.TableEntry do
  @moduledoc """
  Use this module to build table entries creators
  """
  defmacro __using__({_table_name, infos}) do
    %{entry_name: entry_name, indices: _indices, columns: columns} = infos

    quote bind_quoted: [entry_name: entry_name, columns: Macro.escape(columns)] do
      require Record
      alias Snmp.ASN1.Types

      attributes = columns |> Enum.map(&elem(&1, 3))
      Record.defrecord(:entry, entry_name, attributes)

      @doc """
      Returns new record
      """
      def new, do: entry()

      @doc """
           Cast parameters into #{entry_name}

           # Parameters

           """ <> Enum.join(Enum.map(attributes, &"* `#{&1}`"), "\n")
      def cast(entry \\ new(), params) do
        Enum.reduce(params, entry, &__cast_param__/2)
      end

      for {:me, _oid, _entrytype, col_name, _asn1_type, _access, _mfa, _imported, _assocList,
           _description, _units} = me <- columns do
        defp __cast_param__({unquote(col_name), value}, acc) do
          entry(acc, [{unquote(col_name), Types.cast(value, unquote(Macro.escape(me)))}])
        end
      end
    end
  end
end
