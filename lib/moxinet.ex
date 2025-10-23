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
    - `signature_storage`: Name of the signature storage server. Defaults to `Moxinet.SignatureStorage`

  """

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
  Mocks a call for the passed module by defining a signature based on the pid, http method and path. 

  ## Options: 

  * `pid`: The source pid that the mock will be applied for. Defaults to `self()`
  * `times`: The amount of times the mock signature may be used. Defaults to `1`
  * `storage`: The signature storage to be used. Defaults to `Moxinet.SignatureStorage`

  ## Examples:

    Moxinet.expect(MyMock, :get, "/path/to/resource", fn _body ->
      %Moxinet.Response{status: 200, body: "My response body"}
    end)
    
  """
  @type http_method :: :get | :post | :patch | :put | :delete | :options
  @spec expect(
          module(),
          http_method,
          binary(),
          Moxinet.SignatureStorage.Mock.callback(),
          Moxinet.SignatureStorage.store_options()
        ) ::
          :ok
  defdelegate expect(module, http_method, path, callback, options \\ []),
    to: Moxinet.SignatureStorage,
    as: :store
end
