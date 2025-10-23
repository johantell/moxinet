defmodule Moxinet.Adapters.ReqTestAdapter do
  @moduledoc """
  Adapter for `req` which is used to include `Moxinet` functionality into all `req`-made requests.
  """

  alias Req.Request
  alias Req.Response

  @doc """
  Puts the moxinet header onto the req request and continues with `Req.Steps.run_finch/1` which is the normal
  default adapter.
  """
  @spec run(Request.t()) :: Response.t()
  def run(%Request{} = request) do
    {header_name, header_value} = Moxinet.build_mock_header()

    request
    |> Request.put_header(header_name, header_value)
    |> Request.append_response_steps(capture_moxinet_errors: &capture_moxinet_errors/1)
    |> Req.Steps.run_finch()
  end

  @doc false
  @spec capture_moxinet_errors({Request.t(), Response.t()}) :: {Request.t(), Response.t()} | no_return()
  def capture_moxinet_errors({request, response}) do
    case Req.Response.get_header(response, "x-moxinet-error") do
      [error_header] ->
        [error_path] = Req.Response.get_header(response, "x-moxinet-path")
        method = request.method |> to_string() |> String.upcase()

        error_header
        |> Module.split()
        |> List.last()
        |> raise_error(path: error_path, method: method)

      _ ->
        {request, response}
    end
  end

  defp raise_error("InvalidReferenceError", error_details) do
    raise Moxinet.InvalidReferenceError, error_details
  end

  defp raise_error("MissingMockError", error_details) do
    raise Moxinet.MissingMockError, error_details
  end
end
