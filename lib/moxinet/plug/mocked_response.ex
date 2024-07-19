defmodule Moxinet.Plug.MockedResponse do
  @moduledoc false

  import Plug.Conn

  alias Moxinet.Response
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

      {:error, :exceeds_usage_limit} ->
        fail_and_send(conn, "The mocked callback may not be used more than once.")

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
    |> append_uri_query(query_string)
    |> URI.to_string()
  end

  def append_uri_query(%URI{} = uri, query) when is_binary(query) and query !== "" do
    URI.append_query(uri, query)
  end

  def append_uri_query(%URI{} = uri, _query) do
    uri
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

  defp apply_signature(%Plug.Conn{req_headers: request_headers} = conn, callback)
       when is_function(callback) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)

    body = decode_decodable_body(conn, body)

    response =
      callback
      |> run_callback(body, request_headers)
      |> validate_response!()

    conn
    |> put_response_status(response)
    |> put_response_body(response)
  end

  defp decode_decodable_body(%Plug.Conn{} = conn, body) do
    cond do
      body == "" -> nil
      json_body?(conn) -> Jason.decode!(body)
      true -> body
    end
  end

  defp run_callback(callback, body, _request_headers) when is_function(callback, 1) do
    callback.(body)
  end

  defp run_callback(callback, body, request_headers) when is_function(callback, 2) do
    request_headers = Enum.reject(request_headers, &moxinet_header?/1)

    callback.(body, request_headers)
  end

  defp moxinet_header?({"x-moxinet-ref", _}), do: true
  defp moxinet_header?(_), do: false

  defp validate_response!(%Response{} = response), do: response

  defp validate_response!(invalid_response) do
    raise ArgumentError,
          String.trim("""
            Expected mock callback to respond with a `%Moxinet.Response{}` struct, got: `#{inspect(invalid_response)}`
          """)
  end

  defp put_response_status(%Plug.Conn{} = conn, %Response{status: status}) do
    Plug.Conn.put_status(conn, status)
  end

  defp put_response_body(%Plug.Conn{} = conn, %Response{body: body}) do
    case get_req_header(conn, "accept") do
      ["application/json" | _] ->
        conn
        |> put_resp_content_type("application/json")
        |> resp(conn.status, Jason.encode!(body))

      _ ->
        resp(conn, conn.status, to_string(body))
    end
  end

  defp json_body?(%Plug.Conn{req_headers: req_headers}) do
    {"content-type", "application/json"} in req_headers
  end

  defp fail_and_send(conn, error_message) do
    conn
    |> send_resp(500, error_message)
    |> halt()
  end
end
