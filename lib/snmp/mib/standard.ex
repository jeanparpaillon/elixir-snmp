defmodule Snmp.Mib.Standard do
  @moduledoc """
  Describes callbacks for implementing STANDARD-MIB
  """
  @variables [
    :sysUpTime,
    :sysDescr,
    :sysObjectID,
    :sysContact,
    :sysName,
    :sysLocation,
    :sysServices,
    :snmpEnableAuthenTraps,
    :snmpInPkts,
    :snmpOutPkts,
    :snmpInBadVersions,
    :snmpInBadCommunityNames,
    :snmpInBadCommunityUses,
    :snmpInASNParseErrs,
    :snmpInTooBigs,
    :snmpInNoSuchNames,
    :snmpInBadValues,
    :snmpInReadOnlys,
    :snmpInGenErrs,
    :snmpInTotalReqVars,
    :snmpInTotalSetVars,
    :snmpInGetRequests,
    :snmpInGetNexts,
    :snmpInSetRequests,
    :snmpInGetResponses,
    :snmpInTraps,
    :snmpOutTooBigs,
    :snmpOutNoSuchNames,
    :snmpOutBadValues,
    :snmpOutGenErrs,
    :snmpOutGetRequests,
    :snmpOutGetNexts,
    :snmpOutSetRequests,
    :snmpOutGetResponses,
    :snmpOutTraps
  ]

  @required [:sysDescr, :sysObjectID, :sysContact, :sysName, :sysServices, :snmpEnableAuthenTraps]

  for varname <- @variables do
    @callback unquote(varname)(term()) :: term()
  end

  @optional_callbacks (@variables -- @required) |> Enum.map(&{&1, 1})
end
