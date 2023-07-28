defmodule Beacon.Cluster do
  @moduledoc false

  def load_module(node, module) do
    {bin, beam_path} = get_beam_and_path(module)
    :erpc.call(node, :code, :load_binary, [module, beam_path, bin])
  end

  # Copied from https://github.com/elixir-lang/elixir/blob/bc45fabd9c781ca9efaa71971ba2b10cdf14a084/lib/iex/lib/iex/helpers.ex#L1477
  # Originally licensed under Apache 2.0 available at https://www.apache.org/licenses/LICENSE-2.0
  defp get_beam_and_path(module) do
    with {^module, beam, filename} <- :code.get_object_code(module),
         {:ok, ^module} <- beam |> :beam_lib.info() |> Keyword.fetch(:module) do
      {beam, filename}
    else
      _ -> :error
    end
  end
end
