defimpl Jason.Encoder, for: Tuple do
  defdelegate encode(value, opts), to: Beacon.Template.HEEx.JSONEncoder, as: :encode_eex_block
end
