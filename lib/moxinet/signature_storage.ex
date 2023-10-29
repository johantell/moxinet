defmodule Moxinet.SignatureStorage do
  @moduledoc false

  use GenServer

  import Moxinet, only: [pid_reference: 1]

  defmodule Signature do
    @moduledoc false

    defstruct [:mock_module, :pid, :method]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(args) do
    {:ok, args}
  end

  def store(scope, method, callback, from_pid \\ self(), pid \\ __MODULE__) do
    signature = %Signature{
      mock_module: scope,
      pid: pid_reference(from_pid),
      method: method |> to_string() |> String.upcase()
    }

    GenServer.call(pid, {:store, signature, callback})
  end

  def find_signature(scope, from_pid, method, pid \\ __MODULE__) do
    signature = %Signature{
      mock_module: scope,
      pid: pid_reference(from_pid),
      method: method |> to_string() |> String.upcase()
    }

    GenServer.call(pid, {:find_signature, signature})
  end

  def handle_call({:store, %Signature{} = signature, callback}, _from, state) do
    {:reply, :ok, Map.put(state, signature, callback)}
  end

  def handle_call({:find_signature, signature}, _from, state) do
    response =
      case Map.get(state, signature, :not_found) do
        callback when is_function(callback) ->
          {:ok, callback}

        :not_found ->
          {:error, :not_found}
      end

    {:reply, response, state}
  end
end
