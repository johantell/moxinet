defmodule Moxinet.PidReferenceTest do
  use ExUnit.Case, async: true

  alias Moxinet.PidReference

  describe "encode/1" do
    test "encodes a pid to a base64 string" do
      pid = self()
      encoded = PidReference.encode(pid)

      assert is_binary(encoded)
      assert String.match?(encoded, ~r/^[A-Za-z0-9+\/=]+$/)
    end

    test "produces different encoded strings for different pids" do
      pid1 = self()
      pid2 = spawn(fn -> :timer.sleep(:infinity) end)

      encoded1 = PidReference.encode(pid1)
      encoded2 = PidReference.encode(pid2)

      assert encoded1 != encoded2

      Process.exit(pid2, :kill)
    end

    test "produces consistent encoding for the same pid" do
      pid = self()
      encoded1 = PidReference.encode(pid)
      encoded2 = PidReference.encode(pid)

      assert encoded1 == encoded2
    end
  end

  describe "decode/1" do
    test "decodes a valid encoded pid" do
      pid = self()
      encoded = PidReference.encode(pid)

      assert {:ok, decoded_pid} = PidReference.decode(encoded)
      assert decoded_pid == pid
    end

    test "successfully decodes pids from other processes" do
      other_pid = spawn(fn -> :timer.sleep(:infinity) end)
      encoded = PidReference.encode(other_pid)

      assert {:ok, decoded_pid} = PidReference.decode(encoded)
      assert decoded_pid == other_pid

      Process.exit(other_pid, :kill)
    end

    test "returns error for invalid base64 string" do
      invalid_base64 = "not_valid_base64!@#$"

      assert {:error, :invalid_pid_reference} = PidReference.decode(invalid_base64)
    end

    test "returns error for valid base64 but invalid pid binary" do
      # Encode some arbitrary data that's not a pid
      invalid_data = Base.encode64("just some random text")

      assert {:error, :invalid_pid_reference} = PidReference.decode(invalid_data)
    end

    test "returns error for base64-encoded non-pid term" do
      # Encode a valid Erlang term that's not a pid
      non_pid_term = :erlang.term_to_binary(:atom) |> Base.encode64()

      assert {:error, :invalid_pid_reference} = PidReference.decode(non_pid_term)
    end

    test "returns error for empty string" do
      assert {:error, :invalid_pid_reference} = PidReference.decode("")
    end
  end

  describe "encode/1 and decode/1 round-trip" do
    test "can round-trip encode and decode the current process" do
      original_pid = self()

      encoded = PidReference.encode(original_pid)
      {:ok, decoded_pid} = PidReference.decode(encoded)

      assert decoded_pid == original_pid
    end

    test "can round-trip encode and decode multiple pids" do
      pids =
        Enum.map(1..5, fn _ ->
          spawn(fn -> :timer.sleep(:infinity) end)
        end)

      results =
        Enum.map(pids, fn pid ->
          encoded = PidReference.encode(pid)
          {:ok, decoded} = PidReference.decode(encoded)
          {pid, decoded}
        end)

      Enum.each(results, fn {original, decoded} ->
        assert original == decoded
      end)

      Enum.each(pids, fn pid -> Process.exit(pid, :kill) end)
    end
  end
end
