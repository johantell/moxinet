defmodule Moxinet.FakeRouter do
  use Moxinet.Server

  defmodule FakeMock do
    use Moxinet.Mock
  end

  forward("/fakemock", to: FakeMock)
end
