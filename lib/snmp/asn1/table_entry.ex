defmodule Snmp.Mib.Table do
  @moduledoc """
  Use this module to build table entries creators
  """
  defmacro __using__({_table_name, infos}) do
    %{entry_name: entry_name, indices: _indices, attributes: attributes} = infos

    quote do
      require Record

      Record.defrecord :entry, unquote(entry_name), unquote(attributes)
    end
  end
end
