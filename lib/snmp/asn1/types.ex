defmodule Snmp.ASN1.Types do
  @moduledoc """
  Functions for dealing with ASN.1 types
  """
  require Record

  Record.defrecord(:me, Record.extract(:me, from_lib: "snmp/include/snmp_types.hrl"))

  Record.defrecord(
    :asn1_type,
    Record.extract(:asn1_type, from_lib: "snmp/include/snmp_types.hrl")
  )

  alias Snmp.ASN1.TypeError

  @doc """
  Cast value as given MIB entry
  """
  def cast(nil, _), do: nil

  def cast(value, me(asn1_type: asn1_type(bertype: :"OBJECT IDENTIFIER")) = me) when is_atom(value) do
    case :snmpa.name_to_oid(value) do
      {:value, value} -> value
      false -> raise TypeError, type: me, value: value
    end
  end

  def cast(value, me(asn1_type: asn1_type(bertype: :"OBJECT IDENTIFIER")) = me) when is_list(value) do
    if Enum.all?(value, &is_integer/1) do
      value
    else
      raise TypeError, type: me, value: value
    end
  end

  def cast(value, me(asn1_type: asn1_type(bertype: :"OBJECT IDENTIFIER")) = me),
    do: raise TypeError, type: me, value: value

  def cast(value, me(asn1_type: asn1_type(bertype: :"OCTET STRING")) = me) when is_binary(value) do
    String.to_charlist(value)
  rescue
    _ ->
      raise TypeError, type: me, value: value
  end

  def cast(value, me(asn1_type: asn1_type(bertype: :"OCTET STRING"))) when is_list(value) do
    value
  end

  def cast(value, me(asn1_type: asn1_type(bertype: :"OCTET STRING")) = me),
    do: raise TypeError, type: me, value: value

  def cast(value, me(asn1_type: asn1_type(bertype: :INTEGER))) when is_integer(value) do
    value
  end

  def cast(value, me(asn1_type: asn1_type(bertype: :INTEGER, assocList: assocList)) = me) when is_atom(value) do
    with {:enum, enum} when is_list(enum) <- {:enum, Keyword.get(assocList, :enums, false)},
    {:value, value} when is_integer(value) <- {:value, Keyword.get(enum, value)} do
      value
    else
      _ ->
        raise TypeError, type: me, value: value
    end
  end

  def cast(value, typealias) when is_atom(typealias) do
    cast(value, me_from_alias(typealias))
  end

  def me_from_alias(:integer), do: me(asn1_type: asn1_type(bertype: :INTEGER))

  def me_from_alias(:string), do: me(asn1_type: asn1_type(bertype: :"OCTET STRING"))

  def me_from_alias(:oid), do: me(asn1_type: asn1_type(bertype: :"OCTET IDENTIFIER"))
end
