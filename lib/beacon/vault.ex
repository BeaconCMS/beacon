defmodule Beacon.Vault do
  @moduledoc """
  Encryption vault for sensitive data stored in the database (API keys, tokens).

  Uses AES-256-GCM via Cloak. The encryption key must be configured:

      config :beacon, Beacon.Vault,
        ciphers: [
          default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: Base.decode64!("your-32-byte-key-base64")}
        ]

  Generate a key with:

      32 |> :crypto.strong_rand_bytes() |> Base.encode64()
  """
  use Cloak.Vault, otp_app: :beacon
end
