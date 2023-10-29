defmodule Moxinet.ServerTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Moxinet.SignatureStorage

  describe "__using__/1" do
    test "creates a router that can forward requests to servers" do
      defmodule Mock do
        use Moxinet.Mock
      end

      defmodule MockServer do
        use Moxinet.Server

        forward("/external_service", to: Mock)
      end

      {:ok, _pid} = SignatureStorage.start_link(name: SignatureStorage)

      Mock.expect(:get, fn "/mocked_path", _payload ->
        %{status: 418, body: "Hello world"}
      end)

      conn =
        conn(:get, "/external_service/mocked_path")
        |> put_req_header("x-moxinet-ref", Moxinet.pid_reference(self()))

      assert %{status: 418, resp_body: "Hello world"} = MockServer.call(conn, MockServer.init([]))
    end
  end
end
