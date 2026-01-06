defmodule MoxinetTest do
  use ExUnit.Case, async: true

  doctest Moxinet

  defmodule FakeRouter do
    use Plug.Router

    get "/" do
      send_resp(conn, 200, "Hello world")
    end
  end

  describe "start/1" do
    test "starts the `SignatureStorage`" do
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

  describe "allow/2" do
    test "allows a spawned process to access parent process mocks" do
      parent = self()

      Moxinet.FakeRouter.FakeMock.expect(:get, "/fakemock/allowed", fn _body ->
        %Moxinet.Response{status: 200, body: "allowed"}
      end)

      spawn(fn ->
        callers = Process.get(:"$callers") || [self()]

        assert :error = NimbleOwnership.fetch_owner(Moxinet.SignatureStorage, callers, :mocks)

        :ok = Moxinet.allow(parent, self())

        send(parent, NimbleOwnership.fetch_owner(Moxinet.SignatureStorage, callers, :mocks))
      end)

      assert_receive {:ok, ^parent}
    end

    test "returns error when pid_with_access has no ownership" do
      other_pid = spawn(fn -> :ok end)

      task =
        Task.async(fn ->
          Moxinet.allow(other_pid, self())
        end)

      assert {:error, _reason} = Task.await(task)
    end
  end
end
