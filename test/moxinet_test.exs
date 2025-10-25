defmodule MoxinetTest do
  use ExUnit.Case, async: true

  doctest Moxinet

  describe "start/1" do
    test "starts the `SignatureStorage`" do
      defmodule FakeRouter do
        use Plug.Router

        get "/" do
          send_resp(conn, 200, "Hello world")
        end
      end

      {:ok, pid} =
        Moxinet.start(
          port: 0000,
          router: FakeRouter,
          name: FakeMoxinet,
          signature_storage: FakeSignatureStorage
        )

      assert true == Process.alive?(pid)
      assert true == FakeSignatureStorage |> Process.whereis() |> Process.alive?()
    end
  end

  describe "build_mock_header/1" do
    test "returns a tuple with header name and base64 encoded reference of a pid" do
      current_pid = self()
      pid_string = current_pid |> :erlang.term_to_binary() |> Base.encode64()

      assert {"x-moxinet-ref", ^pid_string} = Moxinet.build_mock_header(current_pid)
    end
  end

  describe "pid_reference/1" do
    test "turns a pid into a text reference" do
      pid = self()

      reference = Moxinet.pid_reference(pid)

      assert "" <> _ = reference
      assert 40 = String.length(reference)
    end
  end

  describe "expect/5" do
    test "can be called without the options" do
      assert :ok = Moxinet.expect(__MODULE__, :get, "/path", fn _ -> :ok end)
    end
  end
end
