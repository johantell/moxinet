defmodule Moxinet.Plug.MockedResponseTest do
  use ExUnit.Case, async: true

  alias Moxinet.Plug.MockedResponse
  alias Moxinet.SignatureStorage
  alias Moxinet.Response

  import Plug.Test
  import Plug.Conn

  @opts MockedResponse.init(scope: CustomAPIMock)

  setup_all do
    _ = SignatureStorage.start_link(name: SignatureStorage)

    {:ok, signature_storage: SignatureStorage}
  end

  describe "init/1" do
    test "returns the passed options" do
      assert [scope: CustomAPIMock] == MockedResponse.init(scope: CustomAPIMock)
    end
  end

  describe "call/2" do
    test "responds with applied signature and halts the conn" do
      response_headers = [{"header1", "value1"}, {"header2", "value2"}]
      response_body = %{response: "yes"}

      conn =
        conn(:get, "/path")
        |> put_req_header("x-moxinet-ref", Moxinet.pid_reference(self()))
        |> put_req_header("accept", "application/json")

      SignatureStorage.store(CustomAPIMock, :get, "/path", fn _payload ->
        %Response{status: 200, headers: response_headers, body: response_body}
      end)

      conn = MockedResponse.call(conn, @opts)

      assert :sent == conn.state
      assert 200 == conn.status
      assert conn.resp_body == Jason.encode!(response_body)
      Enum.each(response_headers, &assert(&1 in conn.resp_headers))
    end

    test "considers query params to be part of path" do
      conn =
        conn(:get, "/path?param=true")
        |> put_req_header("x-moxinet-ref", Moxinet.pid_reference(self()))

      SignatureStorage.store(CustomAPIMock, :get, "/path?param=true", fn _payload ->
        %Response{status: 200, body: "test=yes"}
      end)

      assert %Plug.Conn{status: 200} = MockedResponse.call(conn, @opts)
    end

    test "passes payload for non 'application/json' post requests" do
      test_pid = Kernel.self()

      conn =
        conn(:post, "/path", "test=yes")
        |> put_req_header("x-moxinet-ref", Moxinet.pid_reference(self()))

      SignatureStorage.store(CustomAPIMock, :post, "/path", fn payload ->
        Kernel.send(test_pid, {:post_payload, payload})
        %Response{status: 200, body: "test=yes"}
      end)

      _conn = MockedResponse.call(conn, @opts)

      assert_receive {:post_payload, payload}
      assert payload == "test=yes"
    end

    test "responds with a 500-error when no `x-moxinet-ref` header was defined" do
      conn =
        conn(:get, "/path")
        |> put_req_header("accept", "application/json")

      conn = MockedResponse.call(conn, @opts)

      assert :sent == conn.state
      assert 500 == conn.status
      assert "Invalid reference was found in the `x-moxinet-ref` header." <> _ = conn.resp_body
    end

    test "responds with a 500-error with a detailed body when no signatures matched" do
      conn =
        conn(:get, "/path")
        |> put_req_header("x-moxinet-ref", Moxinet.pid_reference(self()))
        |> put_req_header("accept", "application/json")

      conn = MockedResponse.call(conn, @opts)

      assert :sent == conn.state
      assert 500 == conn.status
      assert conn.resp_body =~ "No registered mock was found for the registered pid."
    end

    test "raises an `FunctionClauseError` when signature matches but the anonymous function doesn't" do
      conn =
        conn(:get, "/path")
        |> put_req_header("x-moxinet-ref", Moxinet.pid_reference(self()))
        |> put_req_header("accept", "application/json")

      SignatureStorage.store(CustomAPIMock, :get, "/path", fn %{not_matched: true} ->
        %Response{status: 200, body: %{success: true}}
      end)

      assert_raise FunctionClauseError, fn ->
        MockedResponse.call(conn, @opts)
      end
    end

    test "sends `nil` as payload for an empty request body" do
      test_pid = self()

      conn =
        conn(:post, "/path", "")
        |> put_req_header("x-moxinet-ref", Moxinet.pid_reference(self()))

      SignatureStorage.store(CustomAPIMock, :post, "/path", fn payload ->
        send(test_pid, {:payload, payload})
        %Response{status: 200}
      end)

      MockedResponse.call(conn, @opts)

      assert_receive {:payload, nil}
    end

    test "filters out the `x-moxinet-header` from callback with headers" do
      test_pid = self()

      conn =
        conn(:post, "/path", "")
        |> put_req_header("accept", "application/json")
        |> put_req_header("x-moxinet-ref", Moxinet.pid_reference(self()))
        |> put_req_header("x-special-header", "something")

      SignatureStorage.store(CustomAPIMock, :post, "/path", fn _payload, headers ->
        send(test_pid, {:headers, headers})
        %Response{status: 200}
      end)

      MockedResponse.call(conn, @opts)

      assert_receive {:headers,
                      [{"accept", "application/json"}, {"x-special-header", "something"}]}
    end

    test "raises when callback returns something else than a `%Response{}`" do
      conn =
        put_req_header(
          conn(:post, "/path", ""),
          "x-moxinet-ref",
          Moxinet.pid_reference(self())
        )

      SignatureStorage.store(CustomAPIMock, :post, "/path", fn _payload ->
        %{status: 200}
      end)

      assert_raise ArgumentError,
                   "Expected mock callback to respond with a `%Moxinet.Response{}` struct, got: `%{status: 200}`",
                   fn ->
                     MockedResponse.call(conn, @opts)
                   end
    end

    test "treats a non-string response body as JSON if no accept header is given" do
      conn =
        put_req_header(
          conn(:post, "/path", ""),
          "x-moxinet-ref",
          Moxinet.pid_reference(self())
        )

      SignatureStorage.store(CustomAPIMock, :post, "/path", fn _payload ->
        %Response{status: 200, body: %{status: :ok}}
      end)

      conn = MockedResponse.call(conn, @opts)

      assert 200 == conn.status
      assert {"content-type", "application/json; charset=utf-8"} in conn.resp_headers
      assert ~s({"status":"ok"}) == conn.resp_body
    end
  end
end
