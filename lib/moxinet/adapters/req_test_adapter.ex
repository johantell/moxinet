defmodule Moxinet.Adapters.ReqTestAdapter do
  @moduledoc """
  Adapter for `req` which is used to include `Moxinet` functionality into all `req`-made requests.
  """

  alias Req.Request

  def run(%Request{} = request) do
    {header_name, header_value} = Moxinet.build_mock_header()

    request
    |> Request.put_header(header_name, header_value)
    |> Req.Steps.run_finch()
  end
end
