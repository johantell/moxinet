defmodule Moxinet.SignatureStorage.State do
  @moduledoc false

  alias Moxinet.SignatureStorage.Mock
  alias Moxinet.SignatureStorage.Signature

  @type t :: %__MODULE__{
          signatures: %{Signature.t() => [Mock.t()]},
          monitors: %{pid() => pid()}
        }

  defstruct signatures: %{}, monitors: %{}

  @spec get_signature(t(), Signature.t()) ::
          {{:ok, Mock.callback()}, t()}
          | {{:error, :exceeds_usage_limit | :not_found}, t()}
  def get_signature(%__MODULE__{signatures: signatures} = state, signature) do
    {response, reversed_signatures} =
      signatures
      |> Map.get(signature, [])
      |> Enum.reduce({{:error, :not_found}, []}, fn
        mock, {{:ok, _callback} = matched_mock, mocks} ->
          {matched_mock, [mock | mocks]}

        %Mock{usage_limit: usage_limit, used: used} = mock, {{:error, _}, mocks}
        when used < usage_limit ->
          mock = %{mock | used: used + 1}
          {{:ok, mock.callback}, [mock | mocks]}

        %Mock{usage_limit: usage_limit, used: used} = mock, {{:error, _}, mocks}
        when used >= usage_limit ->
          mock = %{mock | used: used + 1}
          {{:error, :exceeds_usage_limit}, [mock | mocks]}

        mock, {response, mocks} ->
          {response, [mock | mocks]}
      end)

    updated_signatures = Map.put(signatures, signature, Enum.reverse(reversed_signatures))

    {response, %{state | signatures: updated_signatures}}
  end

  @spec put_signature(t(), Signature.t(), Mock.t()) :: t()
  def put_signature(%__MODULE__{signatures: signatures} = state, signature, mock) do
    %{state | signatures: Map.update(signatures, signature, [mock], &(&1 ++ [mock]))}
  end

  @spec remove_signatures_for_pid(t(), pid()) :: t()
  def remove_signatures_for_pid(%__MODULE__{signatures: signatures} = state, test_pid) do
    signatures =
      signatures
      |> Enum.map(fn {signature, mocks} ->
        {signature, Enum.reject(mocks, &(&1.owner == test_pid))}
      end)
      |> Enum.reject(fn {_signature, mocks} -> Enum.empty?(mocks) end)
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
