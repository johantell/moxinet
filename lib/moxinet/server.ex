defmodule Moxinet.Server do
  @moduledoc """
  Supports with building a custom mocking server.

  ## Usage

  While it out of the box will support interactivity
  with `Moxinet.expect/3`, you'll also be able to treat it like
  a Plug and define your own `match` definitions to enable static
  fallbacks.

  ```elixir
  defmodule GithubMock do
    use Moxinet.Server

    match "/pull-requests/closed" do
      send_resp(conn, 200, %{closed: true})
    end
  end
  ```

  Since the mocking server is just another plug, you can
  choose to use/build custom plugs to extend its functionality as
  a way to add extra verification that your API module does what
  you want it to do, or to replicate a complex API interaction.

  ```elixir
  defmodule GithubMock do
    use Moxinet.Server

    import Plug.BasicAuth

    plug :basic_auth, username: "user", password: "s3cr3t_p4s5w0rd"
  end
  ```
  """

  defmacro __using__(_opts) do
    quote do
      unquote(prelude())

      unquote(not_found_matcher())

      def expect(http_method, callback, from_pid \\ self()) do
        Moxinet.expect(__MODULE__, http_method, callback, from_pid)
      end

      def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
        send_resp(conn, conn.status, "Something went wrong")
      end
    end
  end

  defp prelude do
    quote do
      use Plug.Router
      use Plug.ErrorHandler

      import Moxinet

      plug Moxinet.Plug.MockedResponse, scope: __MODULE__
    end
  end

  defp not_found_matcher do
    quote location: :keep, generated: true do
      match _ do
        send_resp(
          var!(conn),
          404,
          "No matching signature was found. Try setting it with `#{__MODULE__}.expect/3`"
        )
      end
    end
  end
end
