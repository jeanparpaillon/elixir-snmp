defmodule Snmp.Plug do
  @moduledoc """
  Plug for exposing MIB through REST API

  # API

  * `/get`: Retrieve MIB objects
    * Params: a list of OIDS
    * Returns:
      ```json
      {
        errors: {
          "1.2.3": "noSuchObject"
        },
        objects: {
          "1.3.6.1.2.1.1.1.0": "SNMP Agent"
        }
      }
      ```
    * Example: GET /get?1.3.6.1.2.1.1.1.0&1.2.3
  """
  use Plug.Builder

  alias Snmp.OID

  plug Plug.Parsers, parsers: []
  plug :mib

  def init(opts) do
    agent = Keyword.get(opts, :agent)

    if Kernel.function_exported?(agent, :__agent__, 1) do
      %{agent: agent}
    else
      raise "Missing/bad parameter for plug #{__MODULE__}: :agent"
    end
  end

  def call(conn, %{agent: agent} = opts) do
    conn
    |> put_private(:snmp_agent, agent)
    |> super(opts)
    |> assign(:called_all_plugs, true)
  end

  def mib(%{path_info: ["get"]} = conn, _opts) do
    case conn.method do
      "GET" -> get(conn, parse_oids(conn.params))
      "_" -> send_resp(conn, 405, "")
    end
  end

  def mib(conn, _opts), do: send_resp(conn, 404, "NOT FOUND")

  def get(conn, :error) do
    send_resp(conn, 400, Jason.encode!(%{errors: %{"oids" => "invalid params"}}))
  end

  def get(conn, {:ok, oids}) when is_list(oids) do
    agent = conn.private[:snmp_agent]

    body =
      oids
      |> Enum.map(&elem(&1, 1))
      |> agent.get()
      |> case do
        {:error, {reason, oid}} ->
          %{errors: %{oid => reason}}

        values ->
          format_objects(oids, values)
      end

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(body))
  end

  defp parse_oids(map) do
    map
    |> Map.keys()
    |> Enum.reduce_while({:ok, []}, fn bin, {:ok, acc} ->
      case OID.parse(bin) do
        {:ok, oid} -> {:cont, {:ok, [{bin, oid} | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      :error -> :error
      {:ok, oids} -> {:ok, Enum.reverse(oids)}
    end
  end

  defp format_objects(oids, values) do
    [oids, values]
    |> Enum.zip()
    |> Enum.reduce(%{errors: %{}, objects: %{}}, fn
      {{bin, _oid}, :noSuchObject}, acc ->
        %{acc | errors: Map.put(acc.errors, bin, :noSuchObject)}

      {{bin, oid}, value}, acc ->
        %{acc | objects: Map.put(acc.objects, bin, object(oid, value))}
    end)
  end

  defp object(oid, value) when is_list(value) do
    %{oid: OID.to_string(oid), value: to_string(value)}
  end

  defp object(oid, value) do
    %{oid: OID.to_string(oid), value: value}
  end
end
