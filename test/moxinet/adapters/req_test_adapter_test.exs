defmodule Moxinet.Adapters.ReqTestAdapterTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Moxinet.Adapters.ReqTestAdapter

  defmodule Mock do
    use Moxinet.Mock, storage: ReqTestStorage
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
    assert ReqTestStorage |> Process.whereis() |> Process.alive?()

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

  test "raises a moxinet error when a mock exceeds its usage limit" do
    Mock.expect(
      :get,
      "/mocked_path",
      fn _ ->
        %Moxinet.Response{status: 200}
      end,
      storage: ReqTestStorage
    )

    request =
      Req.new(
        adapter: &ReqTestAdapter.run/1,
        base_url: "http://0.0.0.0:4568/external_service/mocked_path",
        method: :get,
        retry: false
      )

    _ = Req.Request.run_request(request)

    assert_raise Moxinet.ExceededUsageLimitError, fn ->
      Req.Request.run_request(request)
    end
  end

  test "raises a moxinet error when the `x-moxinet-ref` is invalid" do
    {header_name, _header_value} = Moxinet.build_mock_header()

    Mock.expect(
      :get,
      "/mocked_path",
      fn _ ->
        %Moxinet.Response{status: 200}
      end,
      storage: ReqTestStorage
    )

    request =
      Req.new(
        adapter: &ReqTestAdapter.run/1,
        base_url: "http://0.0.0.0:4568/external_service/mocked_path",
        method: :get,
        retry: false
      )
      |> Req.Request.put_header(header_name, "invalid")

    assert_raise Moxinet.InvalidReferenceError, fn ->
      Req.Request.run_request(request)
    end
  end
end
