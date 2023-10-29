defmodule Moxinet.Server do
  @moduledoc """
  Creates a mocking server where service-specific mocks can be added

  ## Example

  ```elixir
  defmodule MockServer do
    use Moxinet.Server

    forward("/github", to: GithubMock)
  end
  ```
  """

  @doc """
  Turns a module into a Moxinet server

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
