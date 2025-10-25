defmodule Moxinet.UnusedExpectationsError do
  defexception [:test_pid, :signatures]

  alias Moxinet.SignatureStorage.Signature

  def message(%__MODULE__{test_pid: test_pid, signatures: signatures}) do
    String.trim("""
      test with pid `#{inspect(test_pid)}` did not use all expectations defined with `expect/4`

      #{for {%Signature{} = signature, _mock} <- signatures, do: format_unused_signature(signature)}
    """)
  end

  defp format_unused_signature(%Signature{path: path, mock_module: mock_module} = signature) do
    method = String.upcase(to_string(signature.method))

     "#{method} `#{path}` (#{inspect(mock_module)})\n"
  end
end
