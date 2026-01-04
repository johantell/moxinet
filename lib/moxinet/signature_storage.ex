defmodule Moxinet.SignatureStorage do
  @moduledoc false

  alias Moxinet.SignatureStorage.Mock
  alias Moxinet.SignatureStorage.Signature
  alias Moxinet.SignatureStorage.State

  @spec child_spec(Keyword.t()) :: Supervisor.child_spec()
  def child_spec(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    NimbleOwnership.child_spec(name: name)
  end

  @spec start_link(Keyword.t()) :: {:ok, pid()}
  def start_link(opts) do
    case Keyword.fetch(opts, :name) do
      {:ok, name} -> NimbleOwnership.start_link(name: name)
      :error -> NimbleOwnership.start_link([])
    end
  end

  @type store_option :: {:pid, pid()} | {:storage, module() | pid()} | {:times, pos_integer()}
  @type store_options :: [store_option()]

  @spec store(
          module(),
          Moxinet.http_method() | binary(),
          binary(),
          Mock.callback(),
          store_options()
        ) :: :ok
  def store(scope, method, path, callback, options \\ []) do
    %{pid: owner_pid, storage: server, times: usage_limit} =
      options
      |> Keyword.validate!(pid: self(), times: 1, storage: __MODULE__)
      |> Map.new()

    signature = %Signature{
      mock_module: scope,
      method: method |> to_string() |> String.upcase(),
      path: path
    }

    mock = %Mock{
      callback: callback,
      owner: owner_pid,
      usage_limit: usage_limit,
      used: 0
    }

    # Use owner_pid as both the key and owner in NimbleOwnership
    # Metadata is the State struct containing all signatures for this test
    result =
      NimbleOwnership.get_and_update(server, owner_pid, :mocks, fn
        nil -> {:ok, State.put_signature(%State{}, signature, mock)}
        state -> {:ok, State.put_signature(state, signature, mock)}
      end)

    normalize_store_result(result)
  end

  defp normalize_store_result({:ok, :ok}), do: :ok
  defp normalize_store_result({:error, reason}), do: {:error, reason}

  @spec find_signature(
          module(),
          pid(),
          Moxinet.http_method() | binary(),
          binary(),
          pid() | module()
        ) ::
          {:ok, Mock.callback()} | {:error, :exceeds_usage_limit | :not_found}
  def find_signature(scope, from_pid, method, path, server) do
    signature = %Signature{
      mock_module: scope,
      method: method |> to_string() |> String.upcase(),
      path: path
    }

    # from_pid is decoded from the x-moxinet-ref header
    # Due to pid_reference/1 walking $callers, from_pid is always the root test pid
    # It's both the owner and the key in NimbleOwnership
    result =
      NimbleOwnership.get_and_update(server, from_pid, :mocks, fn
        nil ->
          {{:error, :not_found}, nil}

        state ->
          State.get_signature(state, signature)
      end)

    normalize_find_result(result)
  end

  defp normalize_find_result({:ok, {:ok, callback}}), do: {:ok, callback}
  defp normalize_find_result({:ok, {:error, reason}}), do: {:error, reason}
  defp normalize_find_result({:error, _}), do: {:error, :not_found}

  @spec verify_usage!(pid(), pid() | module()) :: :ok | no_return()
  def verify_usage!(test_pid, server) do
    server
    |> NimbleOwnership.get_owned(test_pid)
    |> get_state_for_pid(test_pid)
    |> verify_state!(test_pid)
  end

  defp get_state_for_pid(nil, _test_pid), do: nil
  defp get_state_for_pid(owned, test_pid) when is_map(owned), do: Map.get(owned, test_pid)

  defp verify_state!(nil, _test_pid), do: :ok

  defp verify_state!(%State{} = state, test_pid) do
    case State.unused_signatures(state, test_pid) do
      [] ->
        :ok

      signatures ->
        raise Moxinet.UnusedExpectationsError, test_pid: test_pid, signatures: signatures
    end
  end
end
