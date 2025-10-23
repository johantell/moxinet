defmodule Moxinet.Mock do
  @moduledoc """
  Supports building a custom mock.

  ## Usage

  While it out of the box will support interactivity
  with `Moxinet.expect/4`, you'll also be able to treat it like
  a Plug and define your own `match` definitions to enable static
  fallbacks. See `Plug.Router` docs for more details.

  ```elixir
  defmodule GithubMock do
    use Moxinet.Mock

    get "/pull-requests/closed" do
      send_resp(conn, 200, [%{id: "1", closed: true}])
    end
  end
  ```

  Since the mock is just another plug, you can
  choose to use/build custom plugs to extend its functionality as
  a way to add extra verification that your API module does what
  you want it to do, or to replicate a complex API interaction.

  ```elixir
  defmodule GithubMock do
    use Moxinet.Mock

    import Plug.BasicAuth

    plug :basic_auth, username: "user", password: "s3cr3t_p4s5w0rd"
  end
  ```
  """

  defmacro __using__(opts) do
    storage = Keyword.get(opts, :storage, Moxinet.SignatureStorage)

    quote do
      use Plug.Debugger, otp_app: :moxinet

      unquote(prelude(storage: storage))

      plug :match
      plug :dispatch

      unquote(not_found_matcher())

      def expect(http_method, path, callback, options \\ []) do
        Moxinet.expect(__MODULE__, http_method, path, callback, options)
      end
    end
  end

  defp prelude(storage: storage) do
    quote do
      use Plug.Router

      import Moxinet

      plug Moxinet.Plug.MockedResponse, scope: __MODULE__, storage: unquote(storage)
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
