![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/johantell/moxinet/.github%2Fworkflows%2Felixir.yml)
![Hex.pm Version](https://img.shields.io/hexpm/v/moxinet)
![Hex.pm License](https://img.shields.io/hexpm/l/moxinet)

# Moxinet

HTTP mocking server for Elixir that supports parallel testing — like `mox`, but at the HTTP layer.

HexDocs: https://hexdocs.pm/moxinet

## Installation

Add `moxinet` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:moxinet, "~> 0.7.0", only: :test}
  ]
end
```

## Getting started

### 1. Define a mock server

The mock server is a Plug router that forwards requests to mock modules:

```elixir
# test/support/mock_server.ex

defmodule MyApp.MockServer do
  use Moxinet.Server

  forward("/github", to: GithubMock)
end
```

### 2. Create a mock module

```elixir
# test/support/mock_servers/github_mock.ex

defmodule GithubMock do
  use Moxinet.Mock
end
```

### 3. Start Moxinet in your test helper

Moxinet must be started before `ExUnit.start()`:

```elixir
# test/test_helper.exs
{:ok, _} = Moxinet.start(port: 4040, router: MyApp.MockServer)

ExUnit.start()
```

### 4. Configure your API urls

Point your API at the mock server in the test environment:

```elixir
# config/config.exs
config :my_app, GithubAPI,
  url: "https://api.github.com"

# config/test.exs
config :my_app, GithubAPI,
  url: "http://localhost:4040/github"
```

### 5. Configure the `req` adapter (recommended)

When using the `req` library, configure it to use `Moxinet.Adapters.ReqTestAdapter` in your `test.exs` file. This automatically injects the `x-moxinet-ref` header into all requests, so no manual header management is needed:

```elixir
# config/test.exs
config :req, default_options: [
  adapter: &Moxinet.Adapters.ReqTestAdapter.run/1
]
```

### 6. Write tests

Use `expect/4` to define how your mocks should respond:

```elixir
alias Moxinet.Response

describe "create_pr/1" do
  test "creates a pull request" do
    GithubMock.expect(:post, "/pull-requests/123", fn _payload ->
      %Response{status: 202, body: %{id: "pull-request-id"}, headers: [{"X-Rate-Limit", 10}]}
    end)

    assert {:ok,
      %{
       status: 202,
       body: %{"id" => "pull-request-id"},
       headers: [
         {"X-Rate-Limit", 10},
         {"Content-Type", "application/json"}
       ]
      }
    } = GithubAPI.create_pr(title: "My PR")
  end
end
```

## Core concepts

### `Moxinet.Response`

Every `expect` callback must return a `%Moxinet.Response{}` struct:

```elixir
%Moxinet.Response{
  status: 200,                          # required, integer 100-600
  body: %{key: "value"},                # map, list, or binary (maps/lists are JSON-encoded)
  headers: [{"X-Rate-Limit", "100"}]    # optional response headers
}
```

The `Content-Type: application/json` header is added automatically when the body is a map or list.

### `expect/4` options

Pass options as the fifth argument:

- `times:` — how many times the expectation can be matched (default: `1`)
- `pid:` — the owning pid (default: `self()`)

```elixir
GithubMock.expect(:get, "/events", fn _body ->
  %Moxinet.Response{status: 200, body: []}
end, times: 3)
```

Callbacks can be 1-arity (receives the request body) or 2-arity (receives the request body and headers).

### `allow/2`

By default, `$callers` propagation covers `Task` and most OTP processes automatically. For processes spawned with `spawn/1` or similar, explicitly grant access:

```elixir
test "spawned process uses parent mocks" do
  parent = self()

  GithubMock.expect(:get, "/users", fn _ ->
    %Moxinet.Response{status: 200, body: []}
  end)

  spawn(fn ->
    Moxinet.allow(parent, self())
    MyHTTPClient.get("/users")
  end)
end
```

### `verify_usage!`

All expectations must be consumed by the end of each test — unused expectations raise `Moxinet.UnusedExpectationsError`. This is checked automatically via an `on_exit` callback registered by `expect/4`.

You can also verify explicitly:

```elixir
setup :verify_usage!
```

### Error reference

| Error | Cause |
|---|---|
| `Moxinet.MissingMockError` | No expectation registered for that pid/method/path |
| `Moxinet.ExceededUsageLimitError` | Expectation called more times than its `times:` limit |
| `Moxinet.InvalidReferenceError` | `x-moxinet-ref` header contained an unrecognised value |
| `Moxinet.UnusedExpectationsError` | Test ended with expectations that were never called |

## Using non-`req` HTTP clients

When not using `req`, you must manually include the `x-moxinet-ref` header in your requests. Without it, Moxinet cannot match incoming requests to test processes.

Use `Moxinet.build_mock_header/0` to get the header tuple. Only include this header in the test environment:

```elixir
defmodule GithubAPI do
  def client do
    Req.new([
      # ...
    ])
    |> add_moxinet_header()
  end

  defmacrop add_moxinet_header(req) do
    if Mix.env() == :test do
      quote do
        {header_name, header_value} = Moxinet.build_mock_header()
      
        Req.Request.put_new_header(unquote(req), header_name, header_value)
      end
    else
      quote do
        unquote(req)
      end
    end
  end
end
```

## Static fallbacks and plug composition

The mock server is a Plug, so you can extend it like any other Plug.

Define static catch-all routes alongside dynamic expectations. Static routes are matched after dynamic expectations — use this for responses that never vary across tests:

```elixir
defmodule GithubMock do
  use Moxinet.Mock

  get "/pull-requests/closed" do
    send_resp(conn, 200, Jason.encode!([%{id: "1", closed: true}]))
  end
end
```

Compose with other plugs for shared verification logic:

```elixir
defmodule GithubMock do
  use Moxinet.Mock

  import Plug.BasicAuth
  plug :basic_auth, username: "user", password: "s3cr3t"
end
```

## Why not `mox`?

When testing calls to external servers, `mox` tends to guide you towards replacing the entire HTTP layer. A common pattern:

```elixir
defmodule GithubAPI do
  defmodule HTTPBehaviour do
    @callback post(String.t(), Keyword.t()) :: {:ok, Map.t()} | {:error, :atom}
  end

  defmodule HTTP do
    @behaviour GithubAPI.HTTPBehaviour
    def post(url, opts) do
      # Perform HTTP request
    end
  end

  def create_pr(attrs) do
    impl().post("/pull-requests", body: attrs)
  end

  defp impl, do: Application.get_env(:github_api_http_module, HTTP)
end
```

This works, but has drawbacks:

1. The `HTTP` module remains untested since the test suite never exercises it
2. HTTP client libraries (like Tesla) define headers, authentication, and JSON encoding — custom behavior that filters or encodes data can hide bugs. A `@derive {Jason, only: [...]}` can cause a bug that all tests miss because they verify data sent to the HTTP layer, not the wire

Moxinet fills those gaps while also reducing the need for behaviours and mocks.

## How it works

Moxinet works very similarly to `mox` except it focuses on HTTP requests.

The test pid is registered in the mock registry, where it can later be accessed from inside the mock.

```mermaid
flowchart TD
    TP[Test pid] --> MR[Mock registry]
    GMS <--> MR
    TP --> API[Github API]
    API -.HTTP request.-> MS[Mock server]
    MS --> GMS[Github Mock]
    GMS -.HTTP response.-> API
```
