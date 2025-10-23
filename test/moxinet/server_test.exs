defmodule Moxinet.ServerTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias Moxinet.Response
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

      _ = SignatureStorage.start_link(name: SignatureStorage)

      Mock.expect(:get, "/mocked_path", fn _payload ->
        %Response{status: 418, headers: [{"my-header", "My header value"}], body: "Hello world"}
      end)

      conn =
        conn(:get, "/external_service/mocked_path")
        |> put_req_header("x-moxinet-ref", Moxinet.pid_reference(self()))

      assert %Plug.Conn{status: 418, resp_body: "Hello world", resp_headers: resp_headers} =
               MockServer.call(conn, MockServer.init([]))

      assert {"my-header", "My header value"} in resp_headers
    end
  end
end
