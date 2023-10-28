defmodule Moxinet.SignatureStorageTest do
  use ExUnit.Case, async: true

  alias Moxinet.SignatureStorage

  describe "store/1" do
    test "stores a signature in the storage" do
      {:ok, storage_pid} = SignatureStorage.start_link([])
      method = :post
      test_pid = self()
      callback = fn _, _ -> {:ok, []} end
      pid_reference = Moxinet.pid_reference(test_pid)

      assert :ok = SignatureStorage.store(__MODULE__, method, callback, test_pid, storage_pid)

      assert %{
               %SignatureStorage.Signature{
                 mock_module: __MODULE__,
                 pid: ^pid_reference,
                 method: ^method
               } => ^callback
             } = :sys.get_state(storage_pid)
    end
  end

  describe "find_signature/3" do
    test "finds a signature matching the passed arguments" do
      {:ok, storage_pid} = SignatureStorage.start_link([])
      method = :post
      test_pid = self()
      callback = fn _, _ -> {:ok, []} end

      :ok = SignatureStorage.store(__MODULE__, method, callback, test_pid, storage_pid)

      assert {:ok, ^callback} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, storage_pid)
    end

    test "returns an error when the signature wasn't registered" do
      {:ok, storage_pid} = SignatureStorage.start_link([])
      method = :post
      test_pid = self()

      assert {:error, :not_found} =
               SignatureStorage.find_signature(__MODULE__, test_pid, method, storage_pid)
    end
  end
end
