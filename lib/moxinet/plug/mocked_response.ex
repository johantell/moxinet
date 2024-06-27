defmodule Moxinet.Plug.MockedResponse do
  @moduledoc false

  import Plug.Conn

  alias Moxinet.SignatureStorage

  def init(opts) do
    opts
  end

  def call(conn, scope: scope) do
    with {:ok, pid} <- get_pid_reference(conn),
         {:ok, signature} <-
           SignatureStorage.find_signature(
             scope,
             pid,
             conn.method,
             build_path(conn)
           ) do
      conn
      |> apply_signature(signature)
      |> send_resp()
      |> halt()
    else
      {:error, :missing_pid_reference} ->
        fail_and_send(conn, "Invalid reference was found in the `x-moxinet-ref` header.")

      {:error, :not_found} ->
        fail_and_send(
          conn,
          """
          No registered mock was found for the registered pid.

          #{format_error_details(conn)}
          """
        )
    end
  end

  defp format_error_details(conn) do
    """
    method: #{conn.method}
    path: #{build_path(conn)}
    """
  end

  defp build_path(%Plug.Conn{path_info: path_info, query_string: query_string}) do
    ["/" | path_info]
    |> Path.join()
    |> URI.parse()
    |> then(fn uri ->
      case query_string do
        "" -> uri
        query -> URI.append_query(uri, query)
      end
    end)
    |> URI.to_string()
  end

  defp get_pid_reference(%Plug.Conn{} = conn) do
    with [pid_reference] <- get_req_header(conn, "x-moxinet-ref"),
         {:ok, pid_binary} <- Base.decode64(pid_reference),
         pid when is_pid(pid) <- :erlang.binary_to_term(pid_binary) do
      {:ok, pid}
    else
      _ -> {:error, :missing_pid_reference}
    end
  end

  defp apply_signature(conn, callback) when is_function(callback) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)

    response =
      case conn.method do
        "GET" ->
          callback.(nil)

        _other ->
          body =
            if json_body?(conn) do
              Jason.decode!(body)
            else
              body
            end

          callback.(body)
      end

    conn
    |> put_response_status(response)
    |> put_response_body(response)
  end

  defp put_response_status(conn, response) do
    Plug.Conn.put_status(conn, Map.get(response, :status, 200))
  end

  defp put_response_body(conn, response) do
    body = Map.get(response, :body, "")

    case get_req_header(conn, "accept") do
      ["application/json" | _] ->
        conn
        |> put_resp_content_type("application/json")
        |> resp(conn.status, Jason.encode!(body))

      _ ->
        resp(conn, conn.status, to_string(body))
    end
  end

  defp json_body?(%Plug.Conn{method: "POST"} = conn) do
    {"content-type", "application/json"} in conn.req_headers
  end

  defp json_body?(_), do: false

  defp fail_and_send(conn, error_message) do
    conn
    |> send_resp(500, error_message)
    |> halt()
  end
end
