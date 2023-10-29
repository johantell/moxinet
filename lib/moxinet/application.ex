defmodule Moxinet.Application do
  @moduledoc false

  alias Moxinet.SignatureStorage

  require Logger

  @http_server Application.compile_env(:moxinet, :http_server, Bandit)

  @doc """
  Starts the Moxinet application and related processes necessary to
  fullfil its requirements.

  ## Options

    - `router`: Your custom router module. *required*
    - `port`: The port moxinet will listen to. *required*
    - `name`: Name of the moxinet process. defaults to `Moxinet`

  """
  def start(opts) do
    router = Keyword.fetch!(opts, :router)
    port = Keyword.fetch!(opts, :port)
    name = Keyword.get(opts, :name, Moxinet)

    children = [
      {@http_server, plug: router, scheme: :http, port: port},
      {SignatureStorage, name: SignatureStorage}
    ]

    opts = [strategy: :one_for_one, name: name]

    Supervisor.start_link(children, opts)
  end
end
