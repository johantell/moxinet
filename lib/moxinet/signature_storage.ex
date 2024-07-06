defmodule Moxinet.SignatureStorage do
  @moduledoc false

  use GenServer

  alias Moxinet.SignatureStorage.State

  import Moxinet, only: [pid_reference: 1]

  defmodule Signature do
    @moduledoc false

    @type t :: %__MODULE__{
            mock_module: module(),
            pid: pid(),
            method: :get | :post | :put | :patch | :options,
            path: String.t()
          }

    defstruct [:mock_module, :pid, :method, :path]
  end

  defmodule Mock do
    @moduledoc false

    @type t :: %__MODULE__{
            owner: pid(),
            callback: function(),
            usage_limit: pos_integer(),
            used: non_neg_integer()
          }

    defstruct [:owner, :callback, :usage_limit, :used]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %State{}, opts)
  end

  def init(args) do
    {:ok, args}
  end

  def store(scope, method, path, callback, from_pid \\ self(), pid \\ __MODULE__) do
    signature = %Signature{
      mock_module: scope,
      pid: pid_reference(from_pid),
      method: method |> to_string() |> String.upcase(),
      path: path
    }

    ref = %Mock{
      callback: callback,
      owner: from_pid,
      usage_limit: 1,
      used: 0
    }

    GenServer.call(pid, {:store, signature, ref})
  end

  def find_signature(scope, from_pid, method, path, pid \\ __MODULE__) do
    signature = %Signature{
      mock_module: scope,
      pid: pid_reference(from_pid),
      method: method |> to_string() |> String.upcase(),
      path: path
    }

    GenServer.call(pid, {:find_signature, signature})
  end

  def verify_usage!(test_pid, pid \\ __MODULE__) do
    case GenServer.call(pid, {:unused_signatures, test_pid}) do
      [] ->
        :ok

      signatures ->
        raise Moxinet.UnusedExpectationsError, test_pid: test_pid, signatures: signatures
    end
  end

  def handle_call({:store, %Signature{} = signature, callback}, {from_pid, _ref} = _from, state) do
    state =
      state
      |> State.put_signature(signature, callback)
      |> State.put_monitor(from_pid)

    {:reply, :ok, state}
  end

  def handle_call({:find_signature, signature}, _from, state) do
    {response, state} = State.get_signature(state, signature)

    {:reply, response, state}
  end

  def handle_call({:unused_signatures, test_pid}, _from, state) do
    {:reply, State.unused_signatures(state, test_pid), state}
  end

  def handle_info({:DOWN, _ref, :process, test_pid, reason}, state)
      when reason in [:normal, :shutdown] do
    state =
      state
      |> State.remove_monitor(test_pid)
      |> State.remove_signatures_for_pid(test_pid)

    {:noreply, state}
  end
end
