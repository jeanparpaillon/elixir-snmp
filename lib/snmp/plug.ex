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

  * `/getnext`: Retrieve a list of objects starting from given OID
    * Params: one OID
    * Returns:
      ```json
      {
        errors: {},
        objects: {
          "1.3.6.1.2.1.1.1.0": "SNMP Agent"
        },
        next: "1.3.6.1.3.1"
      }
      ```
  """
  use Plug.Builder

  alias Snmp.Plug.Get
  alias Snmp.Plug.GetNext
  alias Snmp.Plug.GetTable

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
      "GET" -> get(conn, Get.Request.parse(conn))
      _ -> send_resp(conn, 405, "")
    end
  end

  def mib(%{path_info: ["getnext"]} = conn, _opts) do
    case conn.method do
      "GET" -> get_next(conn, GetNext.Request.parse(conn))
      _ -> send_resp(conn, 405, "")
    end
  end

  def mib(%{path_info: ["table" | _]} = conn, _opts) do
    case conn.method do
      "GET" -> get_table(conn, GetTable.Request.parse(conn))
      _ -> send_resp(conn, 405, "")
    end
  end

  def mib(conn, _opts), do: send_resp(conn, 404, "NOT FOUND")

  def get(conn, %{valid?: false} = req) do
    body = Get.Response.encode(req)
    send_resp(conn, 400, Jason.encode!(body))
  end

  def get(conn, %{oids: oids}) when is_list(oids) do
    agent = conn.private[:snmp_agent]

    body =
      oids
      |> Enum.map(&elem(&1, 1))
      |> agent.get()
      |> case do
        {:error, _} = e ->
          Get.Response.encode(e)

        objects ->
          [Enum.map(oids, &elem(&1, 0)), objects]
          |> Enum.zip()
          |> Get.Response.encode()
      end

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(body))
  end

  def get_next(conn, %{valid?: false} = req) do
    body = GetNext.Response.encode(req)
    send_resp(conn, 400, Jason.encode!(body))
  end

  def get_next(conn, %{oid: oid, limit: limit}) do
    agent = conn.private[:snmp_agent]

    body =
      oid
      |> agent.stream()
      |> Enum.take(limit)
      |> GetNext.Response.encode()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(body))
  end

  def get_table(conn, _, %{valid?: false} = req) do
    body = GetTable.Response.encode(req)
    send_resp(conn, 400, Jason.encode!(body))
  end

  def get_table(conn, %{table_name: table_name, start: start, limit: limit}) do
    agent = conn.private[:snmp_agent]

    body =
      table_name
      |> agent.table_stream(start)
      |> Enum.take(limit)
      |> GetTable.Response.encode()

    send_resp(conn, 200, Jason.encode!(body))
  end
end
