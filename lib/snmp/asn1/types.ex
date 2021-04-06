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

  def cast(value, me(asn1_type: asn1_type(bertype: :"OBJECT IDENTIFIER")) = me)
      when is_atom(value) do
    case :snmpa.name_to_oid(value) do
      {:value, value} -> value
      false -> raise TypeError, type: me, value: value
    end
  end

  def cast(value, me(asn1_type: asn1_type(bertype: :"OBJECT IDENTIFIER")) = me)
      when is_list(value) do
    if Enum.all?(value, &is_integer/1) do
      value
    else
      raise TypeError, type: me, value: value
    end
  end

  def cast(value, me(asn1_type: asn1_type(bertype: :"OBJECT IDENTIFIER")) = me),
    do: raise(TypeError, type: me, value: value)

  def cast(value, me(asn1_type: asn1_type(bertype: :"OCTET STRING")) = me)
      when is_binary(value) do
    String.to_charlist(value)
  rescue
    _ ->
      reraise TypeError, [type: me, value: value], __STACKTRACE__
  end

  def cast(value, me(asn1_type: asn1_type(bertype: :"OCTET STRING"))) when is_list(value) do
    value
  end

  def cast(value, me(asn1_type: asn1_type(bertype: :"OCTET STRING")) = me),
    do: raise(TypeError, type: me, value: value)

  def cast(value, me(asn1_type: asn1_type(bertype: :INTEGER))) when is_integer(value) do
    value
  end

  def cast(value, me(asn1_type: asn1_type(bertype: :INTEGER))) when is_integer(value) do
    value
  end

  def cast(value, me(asn1_type: asn1_type(bertype: :INTEGER, assocList: assoc_list)) = me)
      when is_atom(value) do
    with {:enum, enum} when is_list(enum) <- {:enum, Keyword.get(assoc_list, :enums, false)},
         {:value, value} when is_integer(value) <- {:value, Keyword.get(enum, value)} do
      value
    else
      _ ->
        raise TypeError, type: me, value: value
    end
  end

  def cast(value, me(asn1_type: asn1_type(bertype: :Counter32)))
      when is_integer(value) and value >= 0 do
    value
  end

  def cast(value, type_alias) when is_atom(type_alias) do
    cast(value, me_from_alias(type_alias))
  end

  def cast(value, me) do
    raise TypeError, type: me, value: value
  end

  @doc false
  def me_from_alias(:integer), do: me(asn1_type: asn1_type(bertype: :INTEGER))

  def me_from_alias(:string), do: me(asn1_type: asn1_type(bertype: :"OCTET STRING"))

  def me_from_alias(:oid), do: me(asn1_type: asn1_type(bertype: :"OCTET IDENTIFIER"))

  @doc """
  Returns default value for given MIB entry
  """
  def default(me(asn1_type: asn1_type(bertype: :"OBJECT IDENTIFIER"))), do: []

  def default(me(asn1_type: asn1_type(bertype: :"OCTET STRING"))), do: ''

  def default(me(asn1_type: asn1_type(bertype: :INTEGER, assocList: assoc_list))) do
    case Keyword.get(assoc_list, :enums, false) do
      false -> 0
      [{_, i} | _] -> i
    end
  end

  def default(me(asn1_type: asn1_type(bertype: :BITS))), do: 0

  def default(me(asn1_type: asn1_type(bertype: :Counter32))), do: 0

  def default(me(asn1_type: asn1_type(bertype: :Unsigned32))), do: 0

  def default(me(asn1_type: asn1_type(bertype: :TimeTicks))), do: 0

  def default(me(asn1_type: :undefined)), do: nil
end
