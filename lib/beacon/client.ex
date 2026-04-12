defmodule Beacon.Client do
  @moduledoc """
  Platform-specific client for rendering Beacon's platform-agnostic AST.

  This module and all `Beacon.Client.*` submodules are designed for
  extraction into a separate library. They have no compile-time dependencies
  on Beacon core internals — they consume the JSON AST format and produce
  framework-native output.

  Currently implements the LiveView/Phoenix client. Future clients (React,
  Vue, Rails, etc.) would implement the same AST consumption contract in
  their respective languages.
  """
end
