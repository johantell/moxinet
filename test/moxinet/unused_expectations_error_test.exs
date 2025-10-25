defmodule Moxinet.UnusedExpectationsErrorTest do
  use ExUnit.Case, async: true

  alias Moxinet.SignatureStorage.Mock
  alias Moxinet.SignatureStorage.Signature
  alias Moxinet.UnusedExpectationsError

  describe "message/1" do
    test "returns a valuable error" do
      test_pid = self()

      signatures = [
        {%Signature{method: :get, path: "/get"}, %Mock{}},
        {%Signature{method: :post, path: "/post"}, %Mock{}}
      ]

      error = %UnusedExpectationsError{test_pid: test_pid, signatures: signatures}

      error_string = UnusedExpectationsError.message(error)
      assert error_string =~ "GET `/get`"
      assert error_string =~ "POST `/post`"
    end
  end
end
