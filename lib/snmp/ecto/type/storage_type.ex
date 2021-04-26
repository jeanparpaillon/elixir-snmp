defmodule Snmp.Ecto.Type.StorageType do
  @moduledoc """
  Ecto custom type for SNMPv2-TC StorageType
  """
  use Snmp.Mib.TextualConvention,
    mapping: [
      other: 1,
      volatile: 2,
      nonVolatile: 3,
      permanent: 4,
      readOnly: 5
    ]
end
