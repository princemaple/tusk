defmodule Tusk.DynamicSupervisor do
  use DynamicSupervisor

  def start_link(server_opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, [], server_opts)
  end

  def start_child(sup, options) do
    {:ok, companion} = DynamicSupervisor.start_child(sup, {Tusk.Companion, options})

    DynamicSupervisor.start_child(
      sup,
      {
        Tusk.TemporarySupervisor,
        [root_supervisor: sup, companion: companion] ++ options
      }
    )
  end

  def terminate_child(sup, which) do
    GenServer.cast(sup, {:terminate_child, which})
  end

  @impl DynamicSupervisor
  def init([]) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
