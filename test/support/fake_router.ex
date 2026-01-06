defmodule Moxinet.FakeRouter do
  @moduledoc false

  use Moxinet.Server

  defmodule FakeMock do
    @moduledoc false

    use Moxinet.Mock
  end

  forward("/fakemock", to: FakeMock)
end
