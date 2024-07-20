defmodule Moxinet.SignatureStorage.State do
  @moduledoc false

  alias Moxinet.SignatureStorage.Mock
  alias Moxinet.SignatureStorage.Signature

  @type t :: %__MODULE__{
          signatures: %{Signature.t() => Mock.t()},
          monitors: %{pid() => pid()}
        }

  defstruct signatures: %{}, monitors: %{}

  @spec get_signature(t(), Signature.t()) ::
          {{:ok, Mock.callback()}, t()}
          | {{:error, :exceeds_usage_limit | :not_found}, t()}
  def get_signature(%__MODULE__{signatures: signatures} = state, signature) do
    {response, signatures} =
      case Map.get(signatures, signature, :not_found) do
        %Mock{used: used, usage_limit: usage_limit} = mock when used < usage_limit ->
          signatures = Map.put(signatures, signature, %{mock | used: used + 1})
          {{:ok, mock.callback}, signatures}

        %Mock{used: used, usage_limit: usage_limit} when used >= usage_limit ->
          {{:error, :exceeds_usage_limit}, signatures}

        :not_found ->
          {{:error, :not_found}, signatures}
      end

    {response, %{state | signatures: signatures}}
  end

  @spec put_signature(t(), Signature.t(), Mock.t()) :: t()
  def put_signature(%__MODULE__{signatures: signatures} = state, signature, mock) do
    %{state | signatures: Map.put(signatures, signature, mock)}
  end

  @spec remove_signatures_for_pid(t(), pid()) :: t()
  def remove_signatures_for_pid(%__MODULE__{signatures: signatures} = state, test_pid) do
    signatures =
      signatures
      |> Enum.reject(fn {_signature, mock} -> mock.owner == test_pid end)
      |> Map.new()

    %{state | signatures: signatures}
  end

  @spec put_monitor(t(), pid()) :: t()
  def put_monitor(%__MODULE__{monitors: monitors} = state, from_pid) do
    monitors =
      case monitors do
        %{^from_pid => _monitor} ->
          monitors

        _ ->
          Map.put(monitors, from_pid, Process.monitor(from_pid))
      end

    %{state | monitors: monitors}
  end

  @spec remove_monitor(t(), pid()) :: t()
  def remove_monitor(%__MODULE__{monitors: monitors} = state, monitored_pid) do
    %{state | monitors: Map.drop(monitors, [monitored_pid])}
  end
end
