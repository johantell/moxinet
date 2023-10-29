defmodule Moxinet.Router do
  @moduledoc """
  Creates a router for the mocking server where
  service-specific mocks can be added

  ## Example

  ```elixir
  defmodule MockRouter do
    use Moxinet.Router

    forward("/github", to: GithubMock)
  end
  ```
  """

  @doc """
  Turns a module into a Moxinet router

  ## Options

    - `log`: Whether requests should be logged or not. Defaults to `false`

  """
  defmacro __using__(opts) do
    log? = Keyword.get(opts, :log, false)

    quote do
      use Plug.Router
      use Plug.Debugger

      if unquote(log?) do
        plug Plug.Logger
      end

      plug :match
      plug :dispatch
    end
  end
end
