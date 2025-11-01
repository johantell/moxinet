defmodule Moxinet.PidReference do
  @moduledoc """
  Manages encoding and decoding of pids    
  """

  @doc """
  Encodes a pid so that it can be transferred as a string
  """
  @spec encode(pid()) :: binary()
  def encode(pid) when is_pid(pid) do
    pid
    |> :erlang.term_to_binary()
    |> Base.encode64()
  end

  @doc """
  Finds a pid from a binary reference
  """
  @spec decode(binary) :: {:ok, pid} | {:error, :invalid_pid_reference}
  def decode(pid_reference) when is_binary(pid_reference) do
    with {:ok, pid_binary} <- Base.decode64(pid_reference),
         {:ok, term} <- safe_binary_to_term(pid_binary),
         pid when is_pid(pid) <- term do
      {:ok, pid}
    else
      _ ->
        {:error, :invalid_pid_reference}
    end
  end

  defp safe_binary_to_term(binary) do
    {:ok, :erlang.binary_to_term(binary, [:safe])}
  rescue
    ArgumentError ->
      {:error, :invalid_binary}
  end
end
