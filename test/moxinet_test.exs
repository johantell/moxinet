defmodule MoxinetTest do
  use ExUnit.Case

  doctest Moxinet

  describe "build_mock_header/1" do
    test "returns a tuple with header name and base64 encoded reference of a pid" do
      current_pid = self()
      pid_string = current_pid |> :erlang.term_to_binary() |> Base.encode64()

      assert {"x-moxinet-ref", ^pid_string} = Moxinet.build_mock_header(current_pid)
    end
  end
end
