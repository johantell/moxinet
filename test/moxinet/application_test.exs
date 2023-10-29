defmodule Moxinet.ApplicationTest do
  use ExUnit.Case, async: true

  alias Moxinet.Application
  alias Moxinet.SignatureStorage

  import ExUnit.CaptureLog

  describe "start/1" do
    test "starts a `SignatureStorage`" do
      defmodule MyServer do
        use Moxinet.Server

        match _ do
          send_resp(conn, 200, "Hello world")
        end
      end

      {{:ok, pid}, logged} = with_log(fn -> Application.start(router: MyServer, port: 4567) end)

      assert Process.alive?(pid)
      assert SignatureStorage |> Process.whereis() |> Process.alive?()
      assert logged =~ "at 0.0.0.0:4567 (http)"
    end
  end
end
