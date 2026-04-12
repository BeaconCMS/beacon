defmodule Beacon.Actions.Security do
  @moduledoc false

  @doc """
  Sign an action document with HMAC-SHA256.

  The signature covers the JSON-encoded action document, preventing tampering.
  """
  @spec sign(map(), binary()) :: binary()
  def sign(action_document, secret_key) when is_map(action_document) and is_binary(secret_key) do
    payload = Jason.encode!(action_document)
    :crypto.mac(:hmac, :sha256, secret_key, payload) |> Base.encode64()
  end

  @doc """
  Verify an HMAC-SHA256 signature against an action document.
  """
  @spec verify(map(), binary(), binary()) :: boolean()
  def verify(action_document, signature, secret_key)
      when is_map(action_document) and is_binary(signature) and is_binary(secret_key) do
    expected = sign(action_document, secret_key)

    # Constant-time comparison to prevent timing attacks
    byte_size(expected) == byte_size(signature) and :crypto.hash_equals(expected, signature)
  end
end
