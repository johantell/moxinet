defmodule Moxinet.SignatureStorageTest do
  use ExUnit.Case, async: true

  alias Moxinet.SignatureStorage

  describe "store/5" do
    test "stores a signature in the storage" do
      {:ok, storage_pid} = SignatureStorage.start_link([])
      method = :post
      test_pid = self()
      path = "/my-path"
      callback = fn _, _ -> {:ok, []} end

      assert :ok =
               SignatureStorage.store(__MODULE__, method, path, callback,
                 pid: test_pid,
                 storage: storage_pid
               )

      # Verify by retrieving the signature
      assert {:ok, ^callback} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path, storage_pid)
    end

    test "cleans up signatures when process dies" do
      {:ok, storage_pid} = SignatureStorage.start_link([])

      {pid, reference} =
        spawn_monitor(fn ->
          SignatureStorage.store(__MODULE__, :post, "/", fn _ -> :ok end,
            pid: self(),
            storage: storage_pid
          )

          # Verify the signature was stored
          assert {:ok, _} =
                   SignatureStorage.find_signature(__MODULE__, self(), :post, "/", storage_pid)
        end)

      assert_receive {:DOWN, ^reference, :process, ^pid, :normal}
      assert false == Process.alive?(pid)

      # After the process dies, the signature should be cleaned up
      # Trying to find it with the dead pid should fail
      assert {:error, :not_found} =
               SignatureStorage.find_signature(__MODULE__, pid, :post, "/", storage_pid)
    end
  end

  describe "find_signature/3" do
    test "finds a signature matching the passed arguments" do
      {:ok, storage_pid} = SignatureStorage.start_link([])
      method = :post
      test_pid = self()
      path = "/my-path"
      callback = fn _, _ -> {:ok, []} end

      :ok =
        SignatureStorage.store(__MODULE__, method, path, callback,
          pid: test_pid,
          storage: storage_pid
        )

      assert {:ok, ^callback} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path, storage_pid)
    end

    test "returns an error when the signature wasn't registered" do
      {:ok, storage_pid} = SignatureStorage.start_link([])
      method = :post
      path = "/a-path"
      test_pid = self()

      assert {:error, :not_found} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path, storage_pid)
    end

    test "finds a signature amongst multiple others" do
      {:ok, storage_pid} = SignatureStorage.start_link([])
      method = :post
      test_pid = self()
      callback_1 = fn _, _ -> {:ok, [1]} end
      callback_2 = fn _, _ -> {:ok, [2]} end

      :ok =
        SignatureStorage.store(__MODULE__, method, "/my-path", callback_1,
          pid: test_pid,
          storage: storage_pid
        )

      :ok =
        SignatureStorage.store(__MODULE__, method, "/other", callback_2,
          pid: test_pid,
          storage: storage_pid
        )

      assert {:ok, ^callback_1} =
               SignatureStorage.find_signature(
                 __MODULE__,
                 test_pid,
                 method,
                 "/my-path",
                 storage_pid
               )

      assert {:ok, ^callback_2} =
               SignatureStorage.find_signature(
                 __MODULE__,
                 test_pid,
                 method,
                 "/other",
                 storage_pid
               )
    end

    test "only allows a signature to be used once by default" do
      {:ok, storage_pid} = SignatureStorage.start_link([])
      method = :post
      test_pid = self()
      path = "/my-path"
      callback = fn _, _ -> {:ok, []} end

      :ok =
        SignatureStorage.store(__MODULE__, method, path, callback,
          pid: test_pid,
          storage: storage_pid
        )

      assert {:ok, ^callback} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path, storage_pid)

      assert {:error, :exceeds_usage_limit} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path, storage_pid)
    end

    test "allows the `times` option to modify the amount of times a mock my be used" do
      {:ok, storage_pid} = SignatureStorage.start_link([])
      method = :post
      test_pid = self()
      path = "/my-path"
      callback = fn _, _ -> {:ok, []} end

      :ok =
        SignatureStorage.store(__MODULE__, method, path, callback,
          pid: test_pid,
          storage: storage_pid,
          times: 2
        )

      assert {:ok, ^callback} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path, storage_pid)

      assert {:ok, ^callback} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path, storage_pid)

      assert {:error, :exceeds_usage_limit} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path, storage_pid)
    end

    test "cycles to the next matching mock when a usage limit is exceeded" do
      {:ok, storage_pid} = SignatureStorage.start_link([])
      method = :post
      test_pid = self()
      path = "/my-path"
      callback_1 = fn _, _ -> {:ok, []} end
      callback_2 = fn _, _ -> {:ok, []} end

      :ok =
        SignatureStorage.store(__MODULE__, method, path, callback_1,
          pid: test_pid,
          storage: storage_pid,
          times: 2
        )

      :ok =
        SignatureStorage.store(__MODULE__, method, path, callback_2,
          pid: test_pid,
          storage: storage_pid
        )

      assert {:ok, ^callback_1} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path, storage_pid)

      assert {:ok, ^callback_1} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path, storage_pid)

      assert {:ok, ^callback_2} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path, storage_pid)

      assert {:error, :exceeds_usage_limit} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path, storage_pid)
    end
  end
end
