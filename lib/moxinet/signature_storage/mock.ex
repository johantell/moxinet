defmodule Moxinet.SignatureStorage.Mock do
  @moduledoc false

  alias Moxinet.Response

  @type request_body :: String.t()
  @type decoded_json_request_body :: %{String.t() => any()} | [any()]
  @type header :: {String.t(), String.t()}
  @type callback ::
          (request_body() | decoded_json_request_body() -> Response.t())
          | (request_body() | decoded_json_request_body(), [header()] -> Response.t())

  @type t :: %__MODULE__{
          owner: pid(),
          callback: callback(),
          usage_limit: pos_integer(),
          used: non_neg_integer()
        }

  defstruct [:owner, :callback, :usage_limit, :used]

  @doc """
  Returns whether a mock has been depleted (used as many times as it's allowed to be used).
  """
  @spec depleted?(t()) :: boolean
  def depleted?(%__MODULE__{used: used, usage_limit: usage_limit}) do
    used >= usage_limit
  end
end
