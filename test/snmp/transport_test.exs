defmodule Snmp.TransportTest do
  use Snmp.Test.DataCase

  doctest Snmp.Transport, import: true

  alias Snmp.Transport

  property ".config/1" do
    check all(args <- gen_transport_args()) do
      try do
        ret = Transport.config(args)

        assert is_tuple(ret)
        assert tuple_size(ret) in [2, 3, 4]
      rescue
        _ ->
          assert false
      end
    end
  end
end
