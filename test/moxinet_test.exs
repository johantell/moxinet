defmodule MoxinetTest do
  use ExUnit.Case
  doctest Moxinet

  test "greets the world" do
    assert Moxinet.hello() == :world
  end
end
