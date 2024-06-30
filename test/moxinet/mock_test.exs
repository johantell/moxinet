defmodule Moxinet.MockTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Moxinet.SignatureStorage

  setup_all do
    _ = SignatureStorage.start_link(name: SignatureStorage)

    {:ok, signature_storage: SignatureStorage}
  end

  describe "__using__/1" do
    test "builds a custom mock that allows custom expectations" do
      defmodule MyMock do
        use Moxinet.Mock
      end

      conn =
        conn(:post, "/path")
        |> put_req_header("x-moxinet-ref", Moxinet.pid_reference(self()))

      :ok =
        MyMock.expect(:post, "/path", fn _payload -> %{status: 499, body: "My body"} end, self())

      assert %Plug.Conn{status: 499, resp_body: "My body"} = MyMock.call(conn, [])
    end

    test "links the mocked responses to requests made in child processes" do
      defmodule MyChildMock do
        use Moxinet.Mock
      end

      :ok =
        MyChildMock.expect(
          :post,
          "/path",
          fn _payload -> %{status: 499, body: "My body"} end,
          self()
        )

      task =
        Task.async(fn ->
          conn(:post, "/path")
          |> put_req_header("x-moxinet-ref", Moxinet.pid_reference(self()))
          |> MyChildMock.call([])
        end)

      response = Task.await(task)

      assert %Plug.Conn{status: 499, resp_body: "My body"} = response
    end

    test "gives a 500 response when no signature matched" do
      defmodule MyFailingMock do
        use Moxinet.Mock
      end

      conn =
        conn(:post, "/path")
        |> put_req_header("x-moxinet-ref", Moxinet.pid_reference(self()))

      assert %{
               status: 500,
               resp_body: "No registered mock was found for the registered pid." <> _
             } = MyFailingMock.call(conn, [])
    end
  end
end
