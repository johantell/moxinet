# Changelog

## 0.5.0

Good news for everyone using `req`, moxinet can now be integrated seamlessly. 

- Add `Moxinet.ReqTestAdapter` to make integration with `req` seamless
- Improve error handling to raise regular elixir errors over http-content (`req` adapter only)
- Add missing doc

Upgrade guide for `req` users:

1. in `text.exs`, add the following `req` configuration:

```elixir
# config/text.exs
config :req, default_options: [
  adapter: &Moxinet.ReqTestAdapter.run/1
]
```

2. Remove any special way of adding the moxinet header to req requests

## 0.4.0

Another small release:

- Add `headers` to `Moxinet.Response` (allow response headers to be controlled)

## 0.3.0

Updates to dependencies and adding `times` option to `expect`:

- Replace fifth argument in `expect` from `pid` to options.
  In the scenarios where you've used `expect/5`, wrap the value in `times: old_value`.
- Allow `times` option in `expect/5` to limit the amount of times a mock may be used.

## 0.2.1

This version has mostly been about internal improvements, reliability where we'll see more helpful
error messages and easier usage.

- Treat non-binary response bodies as JSON
- Add type specs to all public functions
- Improve consistency in error messages
- Raise when callback functions doesn't return a `Moxinet.Response`
- Clean up signatures after test process shuts down

## 0.2.0

A few minor upgrades to make `expect` both more powerful, but also easier to use.

- Add `%Moxinet.Response{}` struct to formalize responses from `expect` callbacks
- Allow both 1- and 2-arity functions for `expect` callbacks to allow headers to be verified
- Always pass request body to `expect` callbacks (empty bodies will be `nil`)
