defmodule Moxinet.ServerTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Moxinet.SignatureStorage
  alias Moxinet.Response

  describe "__using__/1" do
    test "creates a router that can forward requests to servers" do
      defmodule Mock do
        use Moxinet.Mock
      end

      defmodule MockServer do
        use Moxinet.Server

        forward("/external_service", to: Mock)
      end

      _ = SignatureStorage.start_link(name: SignatureStorage)

      Mock.expect(:get, "/mocked_path", fn _payload ->
        %Response{status: 418, body: "Hello world"}
      end)

      conn =
        conn(:get, "/external_service/mocked_path")
        |> put_req_header("x-moxinet-ref", Moxinet.pid_reference(self()))

      assert %Plug.Conn{status: 418, resp_body: "Hello world"} =
               MockServer.call(conn, MockServer.init([]))
    end
  end
end
