defmodule Beacon.PathParser.Behaviour do
  @callback parse(site :: String.t(), path :: String.t(), params :: map()) :: {String.t(), map()}
end
