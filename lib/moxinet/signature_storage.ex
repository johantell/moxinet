defmodule Moxinet.SignatureStorage do
  @moduledoc false

  alias Moxinet.SignatureStorage.Mock
  alias Moxinet.SignatureStorage.Signature
  alias Moxinet.SignatureStorage.State

  @type store_option :: {:pid, pid()} | {:storage, module() | pid()} | {:times, pos_integer()}
  @type store_options :: [store_option()]

  @spec store(
          module(),
          Moxinet.http_method(),
          binary(),
          Mock.callback(),
          store_options()
        ) :: :ok
  def store(scope, method, path, callback, options \\ []) do
    %{pid: owner_pid, times: usage_limit} =
      options
      |> Keyword.validate!(pid: self(), times: 1)
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

    result =
      NimbleOwnership.get_and_update(__MODULE__, owner_pid, :mocks, fn
        nil -> {:ok, State.put_signature(%State{}, signature, mock)}
        state -> {:ok, State.put_signature(state, signature, mock)}
      end)

    case result do
      {:ok, _result} ->
        :ok

      {:error, _reason} = error ->
        error
    end
  end

  @spec find_signature(
          module(),
          pid(),
          Moxinet.http_method() | binary(),
          binary()
        ) ::
          {:ok, Mock.callback()} | {:error, :exceeds_usage_limit | :not_found}
  def find_signature(scope, test_pid, method, path) do
    result =
      NimbleOwnership.get_and_update(__MODULE__, test_pid, :mocks, fn
        nil ->
          {{:error, :not_found}, nil}

        state ->
          signature = %Signature{
            mock_module: scope,
            method: method |> to_string() |> String.upcase(),
            path: path
          }

          State.get_signature(state, signature)
      end)

    case result do
      {:ok, {:ok, callback}} ->
        {:ok, callback}

      {:ok, {:error, _reason} = error} ->
        error

      {:error, _reason} = error ->
        error
    end
  end

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
