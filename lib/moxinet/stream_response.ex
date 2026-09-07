defmodule Moxinet.StreamResponse do
  @moduledoc """
  A struct for streaming a chunked response back to the caller.

  Unlike `Moxinet.Response`, which describes a complete response returned from
  a mock, a `#{inspect(__MODULE__)}` takes over the connection and lets the mock
  send chunks as they become available.

  Start by wrapping the `Plug.Conn` handed to the mock in `new/1`, then send
  chunks with `send_chunk/2` or `send_chunks/2`:

      Mock.expect(:get, "/streamed_path", fn _payload, _headers, conn ->
        conn
        |> Moxinet.StreamResponse.new()
        |> Moxinet.StreamResponse.send_chunk("first")
        |> Moxinet.StreamResponse.send_chunk("second")
      end)
  """

  @type t :: %__MODULE__{
          conn: Plug.Conn.t(),
          chunks_sent: non_neg_integer()
        }

  defstruct conn: nil, chunks_sent: 0

  alias Plug.Conn

  @doc """
  Starts a chunked response on the given connection.

  Sets the headers required for server-sent events (`content-type`,
  `cache-control` and `connection`) and responds with a `200` status before
  returning the struct used to send chunks.

  The connection must not have been sent yet, meaning its state has to be
  `:unset`.
  """
  @spec new(Conn.t()) :: t()
  def new(%Conn{state: :unset} = conn) do
    conn =
      conn
      |> Conn.put_resp_header("content-type", "text/event-stream")
      |> Conn.put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
      |> Conn.put_resp_header("connection", "keep-alive")
      |> Conn.send_chunked(200)

    %__MODULE__{conn: conn}
  end

  @doc """
  Sends a chunk back over the HTTP connection

  Returns an updated struct with the chunk counter incremented, which is meant
  to be passed to subsequent calls.

  Raises a `RuntimeError` when the client has already closed the connection.
  """
  @spec send_chunk(t(), iodata()) :: t()
  def send_chunk(%__MODULE__{conn: conn, chunks_sent: chunks_sent}, chunk) do
    current_chunk_count = chunks_sent + 1

    case Conn.chunk(conn, chunk) do
      {:ok, conn} ->
        %__MODULE__{conn: conn, chunks_sent: current_chunk_count}

      {:error, :closed} ->
        raise RuntimeError, "Failed to send chunk #{current_chunk_count}. connection was closed."
    end
  end

  @doc """
  Sends a list of chunks back over the HTTP connection, in order.

  Behaves as repeated calls to `send_chunk/2` and raises under the same
  conditions.
  """
  @spec send_chunks(t(), [iodata()]) :: t()
  def send_chunks(%__MODULE__{} = stream_response, chunks) when is_list(chunks) do
    Enum.reduce(chunks, stream_response, fn chunk, stream_response ->
      send_chunk(stream_response, chunk)
    end)
  end
end
