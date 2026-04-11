# Getting Started with Moxinet

This guide walks through setting up Moxinet from scratch in a Phoenix application that calls the GitHub API using `req`.

## Overview

Moxinet is an HTTP mocking server. Instead of replacing your HTTP client with a behaviour and mock (like `mox`), Moxinet runs a local server that your application talks to in tests. This means your full HTTP stack — headers, encoding, authentication — is exercised in every test.

## Step 1: Install Moxinet

Add it to your test dependencies:

```elixir
# mix.exs
defp deps do
  [
    {:moxinet, "~> 0.7.0", only: :test}
  ]
end
```

Run `mix deps.get`.

## Step 2: Create a mock server

The mock server is a router that maps URL prefixes to mock modules. Each external service you call gets its own prefix:

```elixir
# test/support/mock_server.ex

defmodule MyApp.MockServer do
  use Moxinet.Server

  forward("/github", to: MyApp.GithubMock)
  forward("/stripe", to: MyApp.StripeMock)
end
```

## Step 3: Create mock modules

Each mock module handles requests for one external service:

```elixir
# test/support/mocks/github_mock.ex

defmodule MyApp.GithubMock do
  use Moxinet.Mock
end
```

```elixir
# test/support/mocks/stripe_mock.ex

defmodule MyApp.StripeMock do
  use Moxinet.Mock
end
```

That's it — no callbacks or behaviours to define. Expectations are set per-test.

## Step 4: Start Moxinet

Add this to your test helper **before** `ExUnit.start()`:

```elixir
# test/test_helper.exs

{:ok, _} = Moxinet.start(port: 4040, router: MyApp.MockServer)

ExUnit.start()
```

## Step 5: Point your APIs at the mock server

Assume your app has a GitHub API module that reads its base URL from config:

```elixir
# lib/my_app/github_api.ex

defmodule MyApp.GithubAPI do
  def create_pr(attrs) do
    Req.post!(client(), url: "/pull-requests", json: attrs)
  end

  defp client do
    Req.new(base_url: config()[:url])
  end

  defp config, do: Application.fetch_env!(:my_app, __MODULE__)
end
```

In production, this hits the real GitHub API. In tests, point it at Moxinet:

```elixir
# config/config.exs
config :my_app, MyApp.GithubAPI,
  url: "https://api.github.com"

# config/test.exs
config :my_app, MyApp.GithubAPI,
  url: "http://localhost:4040/github"
```

## Step 6: Configure the `req` adapter

This is the recommended approach. It automatically injects the `x-moxinet-ref` header so Moxinet can match requests to test processes:

```elixir
# config/test.exs

config :req, default_options: [
  adapter: &Moxinet.Adapters.ReqTestAdapter.run/1
]
```

> If you're not using `req`, see the [Non-req clients](#non-req-clients) section below.

## Step 7: Write your first test

```elixir
defmodule MyApp.GithubAPITest do
  use ExUnit.Case, async: true

  alias Moxinet.Response

  test "create_pr/1 returns the created pull request" do
    MyApp.GithubMock.expect(:post, "/pull-requests", fn body ->
      assert body["title"] == "My PR"

      %Response{status: 201, body: %{id: "pr-123", title: "My PR"}}
    end)

    assert %{status: 201, body: %{"id" => "pr-123"}} =
             MyApp.GithubAPI.create_pr(%{title: "My PR"})
  end

  test "create_pr/1 handles server errors" do
    MyApp.GithubMock.expect(:post, "/pull-requests", fn _body ->
      %Response{status: 500, body: %{message: "Internal Server Error"}}
    end)

    assert %{status: 500} = MyApp.GithubAPI.create_pr(%{title: "My PR"})
  end
end
```

Key things to notice:

- **`async: true`** works out of the box — each test's expectations are scoped to its process
- The callback receives the **decoded request body**, so you can assert on what your API module actually sent
- Every expectation must be consumed — if a test defines a mock that never gets called, it fails with `UnusedExpectationsError`

## Repeated expectations

If code under test calls the same endpoint multiple times, use the `times` option:

```elixir
MyApp.GithubMock.expect(:get, "/rate-limit", fn _body ->
  %Response{status: 200, body: %{remaining: 100}}
end, times: 3)
```

## Spawned processes

`Task` and most OTP processes inherit access automatically via `$callers`. For plain `spawn`, use `allow/2`:

```elixir
test "background job uses parent mocks" do
  parent = self()

  MyApp.GithubMock.expect(:get, "/users", fn _ ->
    %Response{status: 200, body: []}
  end)

  spawn(fn ->
    Moxinet.allow(parent, self())
    MyApp.GithubAPI.list_users()
  end)
end
```

## Static fallbacks

For responses that never change across tests, define them directly in the mock module. These are matched after dynamic expectations:

```elixir
defmodule MyApp.GithubMock do
  use Moxinet.Mock

  get "/status" do
    send_resp(conn, 200, Jason.encode!(%{status: "ok"}))
  end
end
```

## Non-req clients

Without the `req` adapter, you must manually add the `x-moxinet-ref` header. Use `Moxinet.build_mock_header/0` and only include it in the test environment:

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

Without this header, Moxinet cannot match requests to test processes and will raise `MissingMockError`.
