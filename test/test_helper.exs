Logger.configure(level: :warning)

{:ok, _pid} = Moxinet.start(port: 0000, router: Moxinet.FakeRouter)

ExUnit.start()
