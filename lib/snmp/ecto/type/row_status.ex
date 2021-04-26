defmodule Snmp.Ecto.Type.RowStatus do
  @moduledoc """
  Ecto custom type for SNMPv2-TC RowStatus
  """
  use Snmp.Mib.TextualConvention,
    mapping: [
      active: 1,
      notInService: 2,
      notReady: 3,
      createAndGo: 4,
      createAndWait: 5,
      destroy: 6
    ]
end
