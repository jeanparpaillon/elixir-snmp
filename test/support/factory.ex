defmodule Snmp.Test.Factory do
  @moduledoc """
  Factory module for SNMP
  """
  import ExUnitProperties
  import StreamData

  def gen_transport_args do
    gen all(
          args <-
            one_of([
              tuple({gen_t_domain(), gen_addr()}),
              tuple({gen_t_domain(), gen_e_addr(), gen_t_kind()}),
              tuple({gen_t_domain(), gen_e_addr(), list_of(term())}),
              tuple({gen_t_domain(), gen_e_addr(), gen_t_kind(), list_of(term())})
            ])
        ) do
      args
    end
  end

  def gen_t_domain do
    gen all(
          domain <-
            one_of([
              member_of([:transportDomainUdpIpv4, :transportDomainUdpIpv6]),
              atom(:alias)
            ])
        ) do
      domain
    end
  end

  def gen_addr do
    gen all(
          addr <-
            one_of([
              tuple({gen_ip_addr(), gen_port()}),
              gen_ip_addr()
            ])
        ) do
      addr
    end
  end

  def gen_ip_addr do
    gen all(
          addr <-
            one_of([
              tuple({integer(0..255), integer(0..255), integer(0..255), integer(0..255)}),
              tuple(
                {integer(0..65_535), integer(0..65_535), integer(0..65_535), integer(0..65_535),
                 integer(0..65_535), integer(0..65_535), integer(0..65_535), integer(0..65_535)}
              )
            ])
        ) do
      addr
    end
  end

  def gen_port do
    gen all(port <- integer(0..65_535)) do
      port
    end
  end

  def gen_e_addr do
    gen all(e_addr <- tuple({gen_ip_addr(), gen_port_info()})) do
      e_addr
    end
  end

  def gen_port_info do
    gen all(
          info <-
            one_of([
              gen_port(),
              constant(:system),
              gen_port_range(),
              list_of(gen_port_range())
            ])
        ) do
      info
    end
  end

  def gen_port_range do
    gen all(
          min <- integer(0..65_535),
          max <- integer((min + 1)..65_535)
        ) do
      {min, max}
    end
  end

  def gen_t_kind do
    gen all(kind <- member_of([:req_responder, :trap_sender])) do
      kind
    end
  end
end
