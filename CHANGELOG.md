# Changelog

## 0.2.0

A few minor upgrades to make `expect` both more powerful, but also easier to use.

- Add `%Moxinet.Response{}` struct to formalize responses from `expect` callbacks
- Allow both 1- and 2-arity functions for `expect` callbacks to allow headers to be verified
- Always pass request body to `expect` callbacks (empty bodies will be `nil`)
