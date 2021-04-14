defmodule Snmp.Mib.TableInfo do
  @moduledoc """
  Structure for handling table informations
  """
  require Record

  Record.defrecord(:mib, Record.extract(:mib, from_lib: "snmp/include/snmp_types.hrl"))
  Record.defrecord(:me, Record.extract(:me, from_lib: "snmp/include/snmp_types.hrl"))

  Record.defrecord(
    :asn1_type,
    Record.extract(:asn1_type, from_lib: "snmp/include/snmp_types.hrl")
  )

  Record.defrecord(
    :table_info,
    Record.extract(:table_info, from_lib: "snmp/include/snmp_types.hrl")
  )

  defstruct table_name: nil, entry_name: nil, indices: [], columns: [], infos: nil

  @doc false
  def new({table, infos}, mib) do
    %__MODULE__{table_name: table, infos: infos}
    |> find_entry_name(mib)
    |> find_columns(mib)
    |> find_indices()
    |> cast_composed_index()
    |> cast_index()
  end

  defp find_entry_name(%{table_name: table} = s, mib) do
    entry_name =
      table
      |> lookup_me(mib)
      |> lookup_entry_me(mib)
      |> case do
        nil -> raise "Could not find any entry matching table #{table}"
        me(aliasname: name) -> name
      end

    %{s | entry_name: entry_name}
  end

  defp find_columns(%{table_name: table} = s, mib) do
    columns =
      mib
      |> mib(:mes)
      |> Enum.filter(fn
        me(entrytype: :table_column, assocList: assoc_list) ->
          case Keyword.get(assoc_list, :table_name) do
            ^table -> true
            _ -> false
          end

        _ ->
          false
      end)

    %{s | columns: columns}
  end

  defp find_indices(%{infos: infos} = s) do
    indices =
      table_info(infos, :index_types)
      |> Enum.map(&cast_indices_type/1)

    %{s | indices: indices}
  end

  defp cast_composed_index(%{indices: [index]} = s) do
    %{s | indices: index}
  end

  defp cast_composed_index(%{indices: indices} = s) do
    %{s | indices: List.to_tuple(indices)}
  end

  defp cast_index(%{infos: table_info(first_own_index: 0), indices: indices} = s)
       when is_atom(indices),
       do: add_key_column(s)

  defp cast_index(%{indices: indices} = s) when is_tuple(indices),
    do: add_key_column(s)

  defp cast_index(s),
    do: s

  defp add_key_column(
         %{infos: table_info(first_accessible: fa, nbr_of_cols: noc, index_types: index_types)} =
           s
       ) do
    infos = table_info(s.infos, first_accessible: fa + 1, nbr_of_cols: noc + 1)

    key_type =
      index_types
      |> case do
        [type] -> type
        types -> List.to_tuple(types)
      end

    key =
      me(
        asn1_type: key_type,
        aliasname: :key,
        access: :notAccessible,
        entrytype: :table_column,
        assocList: [table_name: s.table_name]
      )

    %{s | columns: [key | s.columns], infos: infos}
  end

  defp cast_indices_type(asn1_type(bertype: :INTEGER)), do: :integer
  defp cast_indices_type(asn1_type(bertype: :"OCTET STRING")), do: :string
  defp cast_indices_type(asn1_type(bertype: :TimeTicks)), do: :integer
  defp cast_indices_type(asn1_type(bertype: type)), do: type

  defp lookup_me(name, mib) do
    mib
    |> mib(:mes)
    |> Enum.find_value(fn
      me(aliasname: ^name) = me -> me
      _ -> false
    end)
  end

  defp lookup_entry_me(me(oid: oid), mib) do
    r_oid = Enum.reverse(oid)

    mib
    |> mib(:mes)
    |> Enum.find_value(fn
      me(oid: oid, entrytype: :table_entry) = me ->
        case Enum.reverse(oid) do
          [_ | ^r_oid] -> me
          _ -> false
        end

      _ ->
        false
    end)
  end
end
