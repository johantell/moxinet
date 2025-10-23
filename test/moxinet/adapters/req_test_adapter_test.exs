defmodule Moxinet.Adapters.ReqTestAdapterTest do
  use ExUnit.Case, async: true

  alias Moxinet.Adapters.ReqTestAdapter
  import ExUnit.CaptureLog

  defmodule Mock do
    use Moxinet.Mock,
      storage: ReqTestStorage
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
          name: ReqTestServer,
          port: 4568,
          signature_storage: ReqTestStorage
        )
      end)

    assert Process.alive?(pid)
    assert Process.alive?(Process.whereis(ReqTestStorage))

    :ok
  end

  describe "run/1" do
    test "adds the moxinet header to the request headers" do
      {header_name, header_value} = Moxinet.build_mock_header()

      request =
        Req.new(
          adapter: &ReqTestAdapter.run/1,
          base_url: "http://0.0.0.0:4568/external_service/mocked_path",
          method: :get,
          retry: false
        )

      Mock.expect(
        :get,
        "/mocked_path",
        fn _payload ->
          %Moxinet.Response{status: 200, body: "Hello world"}
        end,
        storage: ReqTestStorage
      )

      {request, _response} = Req.Request.run_request(request)

      assert {header_name, header_value} in Req.get_headers_list(request)
    end
  end

  test "raises a moxinet error on a missing mock" do
    request =
      Req.new(
        adapter: &ReqTestAdapter.run/1,
        base_url: "http://0.0.0.0:4568/external_service/mocked_path",
        method: :get,
        retry: false
      )

    assert_raise Moxinet.MissingMockError, fn ->
      Req.Request.run_request(request)
    end
  end
end
