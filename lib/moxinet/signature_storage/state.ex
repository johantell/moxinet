defmodule Moxinet.SignatureStorage.State do
  @moduledoc false

  alias Moxinet.SignatureStorage.Mock
  alias Moxinet.SignatureStorage.Signature

  @type t :: %__MODULE__{
          signatures: %{Signature.t() => [Mock.t()]}
        }

  defstruct signatures: %{}

  @spec get_signature(t(), Signature.t()) ::
          {{:ok, Mock.callback()}, t()}
          | {{:error, :exceeds_usage_limit | :not_found}, t()}
  def get_signature(%__MODULE__{signatures: signatures} = state, signature) do
    {response, reversed_signatures} =
      signatures
      |> Map.get(signature, [])
      |> Enum.reduce({{:error, :not_found}, []}, &find_and_update_usable_mock/2)

    updated_signatures = Map.put(signatures, signature, Enum.reverse(reversed_signatures))

    {response, %{state | signatures: updated_signatures}}
  end

  defp find_and_update_usable_mock(mock, {{:ok, _} = matched_mock, mocks}) do
    {matched_mock, [mock | mocks]}
  end

  defp find_and_update_usable_mock(
         %Mock{used: used, usage_limit: limit} = mock,
         {{:error, _}, mocks}
       )
       when used >= limit do
    {{:error, :exceeds_usage_limit}, [mock | mocks]}
  end

  defp find_and_update_usable_mock(%Mock{used: used} = mock, {{:error, _}, mocks}) do
    mock = %{mock | used: used + 1}

    {{:ok, mock.callback}, [mock | mocks]}
  end

  @spec put_signature(t(), Signature.t(), Mock.t()) :: t()
  def put_signature(%__MODULE__{signatures: signatures} = state, signature, mock) do
    %{state | signatures: Map.update(signatures, signature, [mock], &Enum.concat(&1, [mock]))}
  end

  @spec unused_signatures(t(), pid()) :: [{Signature.t(), [Mock.t()]}]
  def unused_signatures(%__MODULE__{signatures: signatures}, _test_pid) do
    Enum.flat_map(signatures, fn {signature, mocks} ->
      unused_mocks = Enum.reject(mocks, &Mock.depleted?/1)

      if Enum.any?(unused_mocks) do
        [{signature, unused_mocks}]
      else
        []
      end
    end)
  end
end
