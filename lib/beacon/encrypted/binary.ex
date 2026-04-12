defmodule Beacon.Encrypted.Binary do
  @moduledoc false
  use Cloak.Ecto.Binary, vault: Beacon.Vault
end
