defmodule Moxinet.SignatureStorage do
  @moduledoc false

  use GenServer

  import Moxinet, only: [pid_reference: 1]

  alias Moxinet.SignatureStorage.Mock
  alias Moxinet.SignatureStorage.Signature
  alias Moxinet.SignatureStorage.State

  @spec start_link(Keyword.t()) :: {:ok, pid()}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, %State{}, opts)
  end

  @impl GenServer
  def init(args) do
    {:ok, args}
  end

  @type store_option :: {:pid, pid()} | {:storage, module() | pid()} | {:times, pos_integer()}
  @type store_options :: [store_option()]

  @spec store(module(), Moxinet.http_method() | binary(), binary(), Mock.callback(), store_options()) :: :ok
  def store(scope, method, path, callback, options \\ []) do
    %{pid: pid, storage: storage_pid, times: usage_limit} =
      options
      |> Keyword.validate!(pid: self(), times: 1, storage: __MODULE__)
      |> Map.new()

    signature = %Signature{
      mock_module: scope,
      pid: pid_reference(pid),
      method: method |> to_string() |> String.upcase(),
      path: path
    }

    ref =
      %Mock{
        callback: callback,
        owner: pid,
        usage_limit: usage_limit,
        used: 0
      }

    GenServer.call(storage_pid, {:store, signature, ref})
  end

  @spec find_signature(module(), pid(), Moxinet.http_method() | binary(), binary(), pid() | module()) ::
          {:ok, Mock.callback()} | {:error, :exceeds_usage_limit | :not_found}
  def find_signature(scope, from_pid, method, path, pid \\ __MODULE__) do
    signature = %Signature{
      mock_module: scope,
      pid: pid_reference(from_pid),
      method: method |> to_string() |> String.upcase(),
      path: path
    }

    case GenServer.call(pid, {:find_signature, signature}) do
      {:ok, mock_callback} -> {:ok, mock_callback}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl GenServer
  def handle_call({:store, %Signature{} = signature, callback}, {from_pid, _ref} = _from, state) do
    state =
      state
      |> State.put_signature(signature, callback)
      |> State.put_monitor(from_pid)

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:find_signature, signature}, _from, state) do
    {response, state} = State.get_signature(state, signature)

    {:reply, response, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, test_pid, reason}, state)
      when reason in [:normal, :shutdown] do
    state =
      state
      |> State.remove_monitor(test_pid)
      |> State.remove_signatures_for_pid(test_pid)

    {:noreply, state}
  end
end
