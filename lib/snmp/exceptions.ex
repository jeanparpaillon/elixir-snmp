defmodule Snmp.ASN1.TypeError do
  @moduledoc """
  Raised at runtime when a value cannot be casted.
  """
  require Record

  Record.defrecord(:me, Record.extract(:me, from_lib: "snmp/include/snmp_types.hrl"))

  Record.defrecord(
    :asn1_type,
    Record.extract(:asn1_type, from_lib: "snmp/include/snmp_types.hrl")
  )

  defexception [:type, :value]

  def exception(opts) do
    value = Keyword.fetch!(opts, :value)
    type = Keyword.fetch!(opts, :type)
    %__MODULE__{value: value, type: type}
  end

  def message(%__MODULE__{value: value, type: me(asn1_type: asn1_type(bertype: bertype))}) do
    "Can not cast `#{inspect(value)}` into #{bertype}"
  end
end

defmodule Snmp.ASN1.LoadError do
  @moduledoc """
  Raised at runtime when a value cannot be loaded.
  """
  require Record

  Record.defrecord(:me, Record.extract(:me, from_lib: "snmp/include/snmp_types.hrl"))

  Record.defrecord(
    :asn1_type,
    Record.extract(:asn1_type, from_lib: "snmp/include/snmp_types.hrl")
  )

  defexception [:type, :value]

  def exception(opts) do
    value = Keyword.fetch!(opts, :value)
    type = Keyword.fetch!(opts, :type)
    %__MODULE__{value: value, type: type}
  end

  def message(%__MODULE__{value: value, type: me(asn1_type: asn1_type(bertype: bertype))}) do
    "Can not load `#{inspect(value)}` from #{bertype}"
  end
end
