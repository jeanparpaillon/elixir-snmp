defmodule Snmp.Transport do
  @moduledoc """
  Defines SNMP transport types.
  """
  defstruct t_domain: nil, addr: nil, port: nil, port_info: nil, kind: nil, opts: nil

  @typedoc """
  Transport definition type accepted by agent configuration
  """
  @type agent_transport() :: int_agent_transport() | String.t()

  @type int_agent_transport() ::
          {t_domain, addr}
          | {t_domain, e_addr, kind}
          | {t_domain, e_addr, opts}
          | {t_domain, e_addr, kind, opts}
  @type t_domain :: :transportDomainUdpIpv4 | :transportDomainUdpIpv6 | module()
  @type addr :: {ip_addr, :inet.port_number()} | ip_addr
  @type ip_addr :: :inet.ip_address() | snmp_ip_addr()
  @type snmp_ip_addr() :: [non_neg_integer()]
  @type e_addr :: {:inet.ip_address(), port_info()}
  @type port_info :: pos_integer() | :system | range() | ranges()
  @type range() :: {min :: pos_integer(), max :: pos_integer()}
  @type ranges() :: [pos_integer() | range()]
  @type kind :: :req_responder | :trap_sender
  @type opts :: list()

  @doc """
  Cast transport options

  ## Examples

    iex> config("127.0.0.1")
    {:transportDomainUdpIpv4, {127,0,0,1}}

    iex> config({"127.0.0.1", 4000})
    {:transportDomainUdpIpv4, {{127,0,0,1}, 4000}}

    iex> config("::1")
    {:transportDomainUdpIpv6, {0,0,0,0,0,0,0,1}}

    iex> config({MyTransport, "::1"})
    {MyTransport, {0,0,0,0,0,0,0,1}}

    iex> config({MyTransport, {"::1", :system}, :req_responder})
    {MyTransport, {{0,0,0,0,0,0,0,1}, :system}, :req_responder}

    iex> config({MyTransport, {"::1", {4000, 4010}}, :trap_sender})
    {MyTransport, {{0,0,0,0,0,0,0,1}, {4000, 4010}}, :trap_sender}

    iex> config({MyTransport, {"::1", [{4000, 4010}, {8000, 8010}]}, :trap_sender})
    {MyTransport, {{0,0,0,0,0,0,0,1}, [{4000, 4010}, {8000, 8010}]}, :trap_sender}

    iex> config({A, {{0, 0, 0, 0, 0, 0, 0, 0}, 0}})
    {A, {{0, 0, 0, 0, 0, 0, 0, 0}, 0}}
  """
  @spec config(term()) :: int_agent_transport()
  def config(args) do
    %__MODULE__{}
    |> cast(args)
    |> to_tuple()
  end

  ###
  ### Priv
  ###
  defp cast(t, {t_domain, e_addr, kind, opts}) do
    t
    |> cast_domain(t_domain)
    |> cast_e_addr(e_addr)
    |> cast_kind(kind)
    |> cast_opts(opts)
  end

  defp cast(t, {t_domain, e_addr, kind_or_opts}) do
    t
    |> cast_e_addr(e_addr)
    |> cast_domain(t_domain)
    |> cast_kind_or_opts(kind_or_opts)
  end

  defp cast(t, {addr, port}) when is_binary(addr) and is_integer(port) do
    %{t | port: port}
    |> cast_addr(addr)
    |> cast_domain(nil)
  end

  defp cast(t, {t_domain, {addr, port}}) when is_atom(t_domain) and is_integer(port) do
    %{t | port: port}
    |> cast_addr(addr)
    |> cast_domain(t_domain)
  end

  defp cast(t, {t_domain, addr}) when is_atom(t_domain) do
    t
    |> cast_addr(addr)
    |> cast_domain(t_domain)
  end

  defp cast(t, addr) when is_binary(addr) do
    t
    |> cast_addr(addr)
    |> cast_domain(nil)
  end

  defp cast_e_addr(t, {addr, port_info}) do
    t
    |> cast_addr(addr)
    |> cast_port_info(port_info)
  end

  defp cast_addr(t, {_, _, _, _} = a), do: %{t | addr: a}

  defp cast_addr(t, {_, _, _, _, _, _, _, _} = a), do: %{t | addr: a}

  defp cast_addr(t, a) when is_binary(a) do
    {:ok, a} = a |> to_charlist() |> :inet.parse_address()
    %{t | addr: a}
  end

  defp cast_port_info(t, port_info) when is_integer(port_info),
    do: %{t | port_info: port_info}

  defp cast_port_info(t, :system), do: %{t | port_info: :system}

  defp cast_port_info(t, {min, max}) when is_integer(min) and is_integer(max) and min < max,
    do: %{t | port_info: {min, max}}

  defp cast_port_info(t, ranges) when is_list(ranges) do
    ranges =
      ranges
      |> Enum.map(fn
        {min, max} when is_integer(min) and is_integer(max) and min < max ->
          {min, max}
      end)

    %{t | port_info: ranges}
  end

  defp cast_kind_or_opts(t, kind) when kind in [:req_responder, :trap_sender] do
    %{t | kind: kind}
  end

  defp cast_kind_or_opts(t, opts) when is_list(opts) do
    %{t | opts: opts}
  end

  defp cast_kind(t, kind) when kind in [:req_responder, :trap_sender] do
    %{t | kind: kind}
  end

  defp cast_opts(t, opts) when is_list(opts) do
    %{t | opts: opts}
  end

  defp cast_domain(%__MODULE__{t_domain: nil, addr: {_, _, _, _}} = t, nil),
    do: %{t | t_domain: :transportDomainUdpIpv4}

  defp cast_domain(%__MODULE__{t_domain: nil, addr: {_, _, _, _, _, _, _, _}} = t, nil),
    do: %{t | t_domain: :transportDomainUdpIpv6}

  defp cast_domain(t, domain), do: %{t | t_domain: domain}

  defp to_tuple(t) do
    cond do
      not is_nil(t.opts) and not is_nil(t.kind) ->
        {t.t_domain, {t.addr, t.port_info}, t.kind, t.opts}

      not is_nil(t.kind) ->
        {t.t_domain, {t.addr, t.port_info}, t.kind}

      not is_nil(t.opts) ->
        {t.t_domain, {t.addr, t.port_info}, t.opts}

      not is_nil(t.port) ->
        {t.t_domain, {t.addr, t.port}}

      true ->
        {t.t_domain, t.addr}
    end
  end
end
