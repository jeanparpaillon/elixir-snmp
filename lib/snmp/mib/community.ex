defmodule Snmp.Mib.Community do
  @moduledoc """
  Implements SNMP-COMMUNITY-MIB
  """
  @doc false
  def new(attrs) do
    name = Keyword.fetch!(attrs, :name)
    index = Keyword.get(attrs, :index, name)
    sec_name = Keyword.fetch!(attrs, :sec_name)
    ctx_name = Keyword.get(attrs, :context_name, '')
    transport_tag = Keyword.get(attrs, :transport_tag, '')
    {index, name, sec_name, ctx_name, transport_tag}
  end
end
