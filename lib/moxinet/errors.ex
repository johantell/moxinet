defmodule Moxinet.MissingMockError do
  defexception [:method, :path]

  def message(error) do
    String.trim("""
      No registered mock was found for the registered pid.

      method: #{error.method}
      path: #{error.path}
    """)
  end
end

defmodule Moxinet.ExceededUsageLimitError do
  defexception [:method, :path]

  def message(error) do
    String.trim("""
      The mocked callback may not be used more than once.

      method: #{error.method}
      path: #{error.path}
    """)
  end
end

defmodule Moxinet.InvalidReferenceError do
  defexception [:method, :path]

  def message(error) do
    String.trim("""
      Invalid reference was found in the `x-moxinet-ref` header.

      method: #{error.method}
      path: #{error.path}
    """)
  end
end
