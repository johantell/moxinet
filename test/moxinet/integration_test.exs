defmodule Moxinet.IntegrationTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Moxinet.Adapters.ReqTestAdapter

  defmodule Mock do
    use Moxinet.Mock, storage: ReqTestStorage2
  end

  defmodule MockServer do
    use Moxinet.Server

    forward("/external_service", to: Mock)
  end

  setup_all do
    {{:ok, pid}, _logged} =
      with_log(fn ->
        Moxinet.start(
          router: MockServer,
          name: ReqTestServer2,
          port: 4569,
          signature_storage: ReqTestStorage2
        )
      end)

    assert Process.alive?(pid)
    assert ReqTestStorage2 |> Process.whereis() |> Process.alive?()

    :ok
  end

  describe "run/1" do
    test "adds the moxinet header to the request headers" do
      test_pid = self()

      request =
        Req.new(
          adapter: ReqTestAdapter,
          base_url: "http://0.0.0.0:4569/external_service/mocked_path",
          method: :get,
          retry: false,
          into: fn {:data, data}, {req, resp} ->
            send(test_pid, {:chunk, data})

            response = %{resp | body: resp.body <> data}
            {:cont, {req, response}}
          end
        )

      Mock.expect(:get, "/mocked_path", fn _payload, _headers, conn ->
        conn
        |> Moxinet.StreamResponse.new()
        |> Moxinet.StreamResponse.send_chunk("1")
        |> tap(fn _ -> Process.sleep(5) end)
        |> Moxinet.StreamResponse.send_chunk("2.000.000")
        |> tap(fn _ -> Process.sleep(5) end)
        |> Moxinet.StreamResponse.send_chunk("3")
      end)

      {_request, response} = Req.Request.run_request(request)

      assert_receive {:chunk, "1"}
      assert_receive {:chunk, "2.000.000"}
      assert_receive {:chunk, "3"}
      refute_receive {:chunk, "4"}

      assert %Req.Response{body: "12.000.0003"} = response
    end
  end
end
