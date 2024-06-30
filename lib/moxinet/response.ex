defmodule Moxinet.Response do
  @moduledoc """
  A struct to define a response to return from the mock server.
  """

  @type t :: %__MODULE__{
          status: 100..600,
          body: binary() | map() | [any()]
        }

  defstruct status: 200, body: ""
end
