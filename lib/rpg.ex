defmodule Rpg do
  use GenServer

  @default_scope __MODULE__

  def start_link(), do: start_link(@default_scope)

  def start_link(scope) when is_atom(scope) do
    GenServer.start_link(__MODULE__, [scope], name: scope)
  end

  def start(scope) do
    GenServer.start(__MODULE__, [scope], name: scope)
  end
end
