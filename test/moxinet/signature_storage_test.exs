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
      pid_reference = Moxinet.pid_reference(test_pid)

      assert :ok =
               SignatureStorage.store(__MODULE__, method, path, callback, test_pid, storage_pid)

      assert %{
               %SignatureStorage.Signature{
                 mock_module: __MODULE__,
                 pid: ^pid_reference,
                 method: "POST",
                 path: ^path
               } => ^callback
             } = :sys.get_state(storage_pid)
    end
  end

  describe "find_signature/3" do
    test "finds a signature matching the passed arguments" do
      {:ok, storage_pid} = SignatureStorage.start_link([])
      method = :post
      test_pid = self()
      path = "/my-path"
      callback = fn _, _ -> {:ok, []} end

      :ok = SignatureStorage.store(__MODULE__, method, path, callback, test_pid, storage_pid)

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
        SignatureStorage.store(__MODULE__, method, "/my-path", callback_1, test_pid, storage_pid)

      :ok =
        SignatureStorage.store(__MODULE__, method, "/other", callback_2, test_pid, storage_pid)

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
        SignatureStorage.store(__MODULE__, method, path, callback, test_pid, storage_pid)

      assert {:ok, ^callback} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path, storage_pid)

      assert {:error, :not_found} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, path, storage_pid)
    end
  end
end
