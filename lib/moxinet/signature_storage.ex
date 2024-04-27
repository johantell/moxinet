defmodule Moxinet.SignatureStorage do
  @moduledoc false

  use GenServer

  import Moxinet, only: [pid_reference: 1]

  defmodule Signature do
    @moduledoc false

    defstruct [:mock_module, :pid, :method, :path]
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

    GenServer.call(pid, {:store, signature, callback})
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
      case Map.pop(state, signature, :not_found) do
        {callback, state} when is_function(callback) ->
          {{:ok, callback}, state}

        {:not_found, state} ->
          {{:error, :not_found}, state}
      end

    {:reply, response, state}
  end
end
