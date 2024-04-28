defmodule Moxinet.SignatureStorage do
  @moduledoc false

  use GenServer

  import Moxinet, only: [pid_reference: 1]

  defmodule Signature do
    @moduledoc false

    defstruct [:mock_module, :pid, :method, :path]
  end

  defmodule Mock do
    @moduledoc false

    defstruct [:owner, :callback, :usage_limit, :used]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
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

    Process.monitor(from_pid)

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

  def handle_call({:store, %Signature{} = signature, callback}, _from, state) do
    {:reply, :ok, Map.put(state, signature, callback)}
  end

  def handle_call({:find_signature, signature}, _from, state) do
    {response, state} =
      case Map.get(state, signature, :not_found) do
        %Mock{used: used, usage_limit: usage_limit} = mock when used < usage_limit ->
          {{:ok, mock.callback}, Map.put(state, signature, %{mock | used: used + 1})}

        %Mock{used: used, usage_limit: usage_limit} when used >= usage_limit ->
          {{:error, :exceeds_usage_limit}, state}

        :not_found ->
          {{:error, :not_found}, state}
      end

    {:reply, response, state}
  end
end
