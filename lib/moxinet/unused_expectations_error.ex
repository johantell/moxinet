defmodule Moxinet.UnusedExpectationsError do
  defexception [:test_pid, :signatures]

  def message(%__MODULE__{test_pid: test_pid, signatures: signatures}) do
    """
      test with pid `#{inspect(test_pid)}` did not use all expectations defined
      with `Moxinet.expect/4`:

      #{for {signature, _mock} <- signatures do
      String.upcase(to_string(signature.method)) <> " " <> signature.path <> "\n"
    end}
    """
  end
end
