defmodule Moxinet.ResponseTest do
  use ExUnit.Case, async: true

  alias Moxinet.Response

  describe "__struct__/1" do
    test "defaults to `%{status: 200, headers: [], body: ~s()}`" do
      assert %Response{status: 200, headers: [], body: ""} == struct!(Response, %{})
    end
  end
end
