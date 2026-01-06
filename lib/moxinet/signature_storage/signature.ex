defmodule Moxinet.SignatureStorage.Signature do
  @moduledoc false

  @type t :: %__MODULE__{
          mock_module: module(),
          method: String.t(),
          path: String.t()
        }

  defstruct [:mock_module, :method, :path]
end
