defmodule Snmp.Test.DataCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      use ExUnit.Case

      import ExUnitProperties
      import Snmp.Test.Factory
      import StreamData
    end
  end
end
