defmodule Moxinet.SignatureStorageTest do
  use ExUnit.Case, async: true

  alias Moxinet.SignatureStorage

  describe "store/5" do
    test "stores a signature in the storage" do
      method = :post
      test_pid = self()
      path = "/my-path"
      callback = fn _, _ -> {:ok, []} end

      assert :ok =
               SignatureStorage.store(__MODULE__, method, path, callback, pid: test_pid)

      assert {:ok, ^callback} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path)
    end

    test "cleans up signatures when process dies" do
      {pid, reference} =
        spawn_monitor(fn ->
          SignatureStorage.store(__MODULE__, :post, "/", fn _ -> :ok end, pid: self())

          assert {:ok, _} =
                   SignatureStorage.find_signature(__MODULE__, self(), :post, "/")
        end)

      assert_receive {:DOWN, ^reference, :process, ^pid, :normal}
      assert false == Process.alive?(pid)

      assert {:error, :not_found} =
               SignatureStorage.find_signature(__MODULE__, pid, :post, "/")
    end
  end

  describe "find_signature/3" do
    test "finds a signature matching the passed arguments" do
      method = :post
      test_pid = self()
      path = "/my-path"
      callback = fn _, _ -> {:ok, []} end

      :ok =
        SignatureStorage.store(__MODULE__, method, path, callback, pid: test_pid)

      assert {:ok, ^callback} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path)
    end

    test "returns an error when the signature wasn't registered" do
      method = :post
      path = "/a-path"
      test_pid = self()

      assert {:error, :not_found} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path)
    end

    test "finds a signature amongst multiple others" do
      method = :post
      test_pid = self()
      callback_1 = fn _, _ -> {:ok, [1]} end
      callback_2 = fn _, _ -> {:ok, [2]} end

      :ok =
        SignatureStorage.store(__MODULE__, method, "/my-path", callback_1, pid: test_pid)

      :ok =
        SignatureStorage.store(__MODULE__, method, "/other", callback_2, pid: test_pid)

      assert {:ok, ^callback_1} =
               SignatureStorage.find_signature(
                 __MODULE__,
                 test_pid,
                 method,
                 "/my-path"
               )

      assert {:ok, ^callback_2} =
               SignatureStorage.find_signature(
                 __MODULE__,
                 test_pid,
                 method,
                 "/other"
               )
    end

    test "only allows a signature to be used once by default" do
      method = :post
      test_pid = self()
      path = "/my-path"
      callback = fn _, _ -> {:ok, []} end

      :ok =
        SignatureStorage.store(__MODULE__, method, path, callback, pid: test_pid)

      assert {:ok, ^callback} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path)

      assert {:error, :exceeds_usage_limit} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path)
    end

    test "allows the `times` option to modify the amount of times a mock my be used" do
      method = :post
      test_pid = self()
      path = "/my-path"
      callback = fn _, _ -> {:ok, []} end

      :ok =
        SignatureStorage.store(__MODULE__, method, path, callback,
          pid: test_pid,
          times: 2
        )

      assert {:ok, ^callback} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path)

      assert {:ok, ^callback} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path)

      assert {:error, :exceeds_usage_limit} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path)
    end

    test "cycles to the next matching mock when a usage limit is exceeded" do
      method = :post
      test_pid = self()
      path = "/my-path"
      callback_1 = fn _, _ -> {:ok, []} end
      callback_2 = fn _, _ -> {:ok, []} end

      :ok =
        SignatureStorage.store(__MODULE__, method, path, callback_1,
          pid: test_pid,
          times: 2
        )

      :ok =
        SignatureStorage.store(__MODULE__, method, path, callback_2, pid: test_pid)

      assert {:ok, ^callback_1} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path)

      assert {:ok, ^callback_1} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path)

      assert {:ok, ^callback_2} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path)

      assert {:error, :exceeds_usage_limit} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path)
    end
  end
end
