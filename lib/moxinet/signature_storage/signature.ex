defmodule Moxinet.SignatureStorage.Signature do
  @moduledoc false

  @type t :: %__MODULE__{
          mock_module: module(),
          pid: pid(),
          method: :get | :post | :put | :patch | :options,
          path: String.t()
        }

  defstruct [:mock_module, :pid, :method, :path]
end
