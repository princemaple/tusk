defmodule Tusk.DynamicSupervisor do
  use DynamicSupervisor

  @spec start_link(GenServer.options()) :: GenServer.on_start()
  def start_link(server_opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, [], server_opts)
  end

  @spec start_child(Supervisor.supervisor(), [Tusk.option()]) ::
          DynamicSupervisor.on_start_child()
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

  @impl DynamicSupervisor
  def init([]) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
