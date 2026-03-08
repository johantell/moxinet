# Moxinet Usage Rules

Moxinet is an HTTP mocking library for Elixir that enables parallel testing by routing HTTP requests to a local mock server instead of real external services. It follows the same ownership model as `mox` but operates at the HTTP layer.

## Setup

Start Moxinet before `ExUnit.start()` in `test/test_helper.exs`:

```elixir
{:ok, _} = Moxinet.start(port: 4040, router: MyApp.MockServer)
ExUnit.start()
```

Define a mock server using `Moxinet.Server` and route paths to mock modules:

```elixir
defmodule MyApp.MockServer do
  use Moxinet.Server

  forward("/github", to: GithubMock)
  forward("/stripe", to: StripeMock)
end
```

Each mock module uses `Moxinet.Mock`:

```elixir
defmodule GithubMock do
  use Moxinet.Mock
end
```

Point your API config at the mock server in `config/test.exs`:

```elixir
config :my_app, GithubAPI,
  url: "http://localhost:4040/github"
```

## Using `req` (recommended)

When using the `req` library, configure the adapter in `config/test.exs` to automatically inject the `x-moxinet-ref` header into all requests:

```elixir
config :req, default_options: [
  adapter: &Moxinet.Adapters.ReqTestAdapter.run/1
]
```

This is the simplest integration — no manual header management needed.

## Using other HTTP clients

If not using `req`, manually add the `x-moxinet-ref` header to outgoing requests. Use `Moxinet.build_mock_header/0` to get the header tuple:

```elixir
{header_name, header_value} = Moxinet.build_mock_header()
```

Only include this header in the test environment:

```elixir
defmacrop add_moxinet_header(req) do
  if Mix.env() == :test do
    quote do
      {name, value} = Moxinet.build_mock_header()
      put_header(unquote(req), name, value)
    end
  else
    quote do: unquote(req)
  end
end
```

Without `x-moxinet-ref`, Moxinet cannot match the incoming request to the correct test process and the mock will not be found.

## Setting expectations with `expect/4`

Use `expect/4` (or `expect/5`) to register a mock response for a specific HTTP method and path:

```elixir
GithubMock.expect(:get, "/users/123", fn _body ->
  %Moxinet.Response{status: 200, body: %{id: 123, login: "octocat"}}
end)
```

Or via the top-level module:

```elixir
Moxinet.expect(GithubMock, :post, "/pull-requests", fn body ->
  %Moxinet.Response{status: 201, body: %{id: "pr-1"}}
end)
```

### Options for `expect`

- `times:` — how many times the expectation may be matched (default: `1`)
- `pid:` — the owning pid (default: `self()`)
- `storage:` — override the signature storage (rarely needed)

```elixir
GithubMock.expect(:get, "/events", fn _body ->
  %Moxinet.Response{status: 200, body: []}
end, times: 3)
```

## `Moxinet.Response`

Return a `%Moxinet.Response{}` struct from every callback:

```elixir
%Moxinet.Response{
  status: 200,            # integer, 100–600
  body: %{key: "value"}, # map, list, or binary — maps/lists are JSON-encoded
  headers: [{"X-Rate-Limit", "100"}]
}
```

The `Content-Type: application/json` header is added automatically when the body is a map or list.

## Verifying expectations

All expectations must be consumed by the end of each test. Unused expectations raise `Moxinet.UnusedExpectationsError`. This is checked automatically via an `on_exit` callback registered by `expect/4`.

To also verify in setup (e.g. for async tests with `setup`):

```elixir
setup :verify_usage!
```

Or call it directly when needed:

```elixir
Moxinet.verify_usage!(self())
```

## Allowing access from spawned processes

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

`Moxinet.allow/2` accepts a pid or a zero-arity function returning a pid (useful for lazy resolution).

## Static fallbacks in mock modules

`Moxinet.Mock` is a `Plug.Router`, so you can define static catch-all routes alongside dynamic expectations:

```elixir
defmodule GithubMock do
  use Moxinet.Mock

  get "/pull-requests/closed" do
    send_resp(conn, 200, Jason.encode!([%{id: "1", closed: true}]))
  end
end
```

Static routes are matched after dynamic expectations. Use this for responses that never vary across tests.

## Extending mocks with plugs

Because `Moxinet.Mock` is a plug, you can compose it with other plugs for shared verification logic:

```elixir
defmodule GithubMock do
  use Moxinet.Mock

  import Plug.BasicAuth
  plug :basic_auth, username: "user", password: "s3cr3t"
end
```

## Error reference

| Error | Cause |
|---|---|
| `Moxinet.MissingMockError` | Request arrived but no expectation was registered for that pid/method/path |
| `Moxinet.ExceededUsageLimitError` | Expectation was called more times than its `times:` limit |
| `Moxinet.InvalidReferenceError` | `x-moxinet-ref` header was present but contained an unrecognised value |
| `Moxinet.UnusedExpectationsError` | Test ended with expectations that were never called |

## Common mistakes

- **Forgetting `x-moxinet-ref`** — requests from non-`req` clients will hit the mock server but return a 404 or `MissingMockError` because Moxinet cannot link the request to a test pid.
- **Setting `times: n` too low** — if the code under test calls the same endpoint more than `n` times, the request raises `ExceededUsageLimitError`.
- **Defining expectations after the request is made** — `expect/4` must be called before the code that triggers the HTTP request.
- **Not starting Moxinet before `ExUnit.start()`** — the server must be running before tests execute.
