defmodule Moxinet do
  @moduledoc """
  `Moxinet` helps you mock the internet at the HTTP layer
  without sacrificing parallel testing.
  """

  @doc """
  The start functions which will start the `Moxinet` server.

  You'd most likely want to put run this function from
  your `test_helper.exs`:

  ```elixir
  {:ok, _pid} = Moxinet.start(router: MyMockServer, port: 4010)
  ```

  ## Options

    - `router`: A reference to your mock server. *Required*
    - `port`: The port your mock server will run on. *Required*
    - `name`: Name of the moxinet supervisor. Defaults to `Moxinet`

  """

  alias Moxinet.Response

  @spec start(Keyword.t()) :: {:ok, pid} | {:error, atom()}
  defdelegate start(opts), to: Moxinet.Application

  @doc """
  Returns the header needed to be included in requests to the
  mock servers in order to support parallel runs.
  """
  @spec build_mock_header(pid()) :: {String.t(), String.t()}
  def build_mock_header(pid \\ self()) when is_pid(pid) do
    {"x-moxinet-ref", pid_reference(pid)}
  end

  @doc """
  Turns a pid into a reference which could be used for indexing
  the signatures.
  """
  @spec pid_reference(pid()) :: String.t()
  def pid_reference(pid) when is_pid(pid) do
    base_pid =
      case Process.get(:"$callers") do
        [first_pid | _rest] -> first_pid
        _ -> pid
      end

    base_pid
    |> :erlang.term_to_binary()
    |> Base.encode64()
  end

  @doc """
  Mocks a call for the passed module when used from a certain pid, defaulting `self()`
  """
  @type http_method :: :get | :post | :patch | :put | :delete | :options
  @type request_body :: String.t()
  @type decoded_json_request_body :: %{String.t() => any()} | [any()]
  @type header :: {String.t(), String.t()}
  @type mock_function ::
          (request_body() | decoded_json_request_body() -> Response.t())
          | (request_body() | decoded_json_request_body(), [header()] -> Response.t())
  @spec expect(module(), http_method, binary(), mock_function(), pid) :: :ok
  defdelegate expect(module, http_method, path, callback, from_pid \\ self()),
    to: Moxinet.SignatureStorage,
    as: :store

  @doc """
  Verifies that all defined expectations have been called to prevent tests from
  defining expectations that aren't used. Recommended usage is to set it up in
  your test setup:

  ```elixir
  setup :verify_usage!    
  ```
  """
  @spec verify_usage!(pid()) :: :ok | no_return()
  defdelegate verify_usage!(test_pid, storage_pid \\ Moxinet.SignatureStorage),
    to: Moxinet.SignatureStorage
end
