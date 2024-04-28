defmodule Moxinet.Application do
  @moduledoc false

  alias Moxinet.SignatureStorage

  require Logger

  @http_server Application.compile_env(:moxinet, :http_server, Bandit)

  def start(opts) do
    opts = Keyword.validate!(opts, [:router, :port, :name, :signature_storage])

    router = Keyword.fetch!(opts, :router)
    port = Keyword.fetch!(opts, :port)
    name = Keyword.get(opts, :name, Moxinet)
    signature_storage = Keyword.get(opts, :signature_storage, SignatureStorage)

    children = [
      {@http_server, plug: router, scheme: :http, port: port},
      {SignatureStorage, name: signature_storage}
    ]

    opts = [strategy: :one_for_one, name: name]

    Supervisor.start_link(children, opts)
  end
end
