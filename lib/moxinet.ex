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
    callers = Process.get(:"$callers") || [pid]

    case NimbleOwnership.fetch_owner(Moxinet.SignatureStorage, callers, :mocks) do
      {:ok, owner_pid} ->
        Moxinet.PidReference.encode(owner_pid)

      {:shared_owner, shared_owner_pid} ->
        Moxinet.PidReference.encode(shared_owner_pid)

      :error ->
        Moxinet.PidReference.encode(pid)
    end
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
  def expect(module, http_method, path, callback, options \\ []) do
    test_pid = self()
    storage = Keyword.get(options, :storage, Moxinet.SignatureStorage)

    :ok = setup_exunit_callback(test_pid, storage)

    Moxinet.SignatureStorage.store(module, http_method, path, callback, options)
  end

  defp setup_exunit_callback(test_pid, storage) do
    ExUnit.Callbacks.on_exit({Moxinet, self()}, fn ->
      verify_usage!(test_pid, storage)
    end)
  end

  @doc """
  Allows `pid_to_allow` to use mocks defined by `pid_with_access`.

  This is useful when a test spawns processes that need access to the tests
  expectations. By default, most mocks set up with `expect/5` will work out of the box
  but in scenarios where the allowance cannot be inferred through `$callers`,
  it must be explicitly defined.

  ## Example

  A common use case is when the code under test spawns a process that makes HTTP requests:

      test "spawned process can use parent mocks" do
        parent = self()

        Moxinet.expect(MyMock, :get, "/users", fn _body ->
          %Moxinet.Response{status: 200, body: ~s({"id": 1})}
        end)

        task =
          spawn(fn ->
            Moxinet.allow(parent, self())

            # Now this process can make requests that use the mock
            {:ok, response} = MyHTTPClient.get("/users")
            response

            send(parent, response)
          end)

        assert_receive %{id: 1}
      end

  """
  @spec allow(pid(), pid() | (-> pid())) :: :ok | {:error, NimbleOwnership.Error.t()}
  def allow(pid_with_access, pid_to_allow)
      when is_pid(pid_with_access) and (is_pid(pid_to_allow) or is_function(pid_to_allow, 0)) do
    NimbleOwnership.allow(Moxinet.SignatureStorage, pid_with_access, pid_to_allow, :mocks)
  end

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
