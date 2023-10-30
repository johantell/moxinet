defmodule Moxinet.MockTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Moxinet.SignatureStorage

  describe "__using__/1" do
    test "builds a custom mock that allows custom expectations" do
      defmodule MyMock do
        use Moxinet.Mock
      end

      {:ok, _pid} = SignatureStorage.start_link(name: SignatureStorage)

      conn =
        conn(:post, "/path")
        |> put_req_header("x-moxinet-ref", Moxinet.pid_reference(self()))

      :ok =
        MyMock.expect(:post, fn "/path", _payload -> %{status: 499, body: "My body"} end, self())

      assert %Plug.Conn{status: 499, resp_body: "My body"} = MyMock.call(conn, [])
    end

    test "gives a 500 response when no signature matched" do
      defmodule MyFailingMock do
        use Moxinet.Mock
      end

      {:ok, _pid} = SignatureStorage.start_link(name: SignatureStorage)

      conn =
        conn(:post, "/path")
        |> put_req_header("x-moxinet-ref", Moxinet.pid_reference(self()))

      assert %{
               status: 500,
               resp_body: "No registered mock was found for the registered pid."
             } = MyFailingMock.call(conn, [])
    end
  end
end