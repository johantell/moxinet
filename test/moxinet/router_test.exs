defmodule Moxinet.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Moxinet.SignatureStorage

  describe "__using__/1" do
    test "creates a router that can forward requests to servers" do
      defmodule MockServer do
        use Moxinet.Mock
      end

      defmodule MockRouter do
        use Moxinet.Router

        forward("/external_service", to: MockServer)
      end

      {:ok, _pid} = SignatureStorage.start_link(name: SignatureStorage)

      MockServer.expect(:get, fn "/mocked_path", _payload ->
        %{status: 418, body: "Hello world"}
      end)

      conn =
        conn(:get, "/external_service/mocked_path")
        |> put_req_header("x-moxinet-ref", Moxinet.pid_reference(self()))

      assert %{status: 418, resp_body: "Hello world"} = MockRouter.call(conn, MockRouter.init([]))
    end
  end
end
