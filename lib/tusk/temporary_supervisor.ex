defmodule Tusk.TemporarySupervisor do
  use Supervisor, restart: :temporary

  def start_link(options) do
    Supervisor.start_link(__MODULE__, options)
  end

  def init(options) do
    {sup_opts, options} =
      Keyword.split(options, [:max_seconds, :max_restarts])

    GenServer.call(Keyword.fetch!(options, :companion), :supervisor)

    Supervisor.init(
      [{Tusk, options}],
      Keyword.merge(
        [strategy: :one_for_one, max_restarts: 1],
        sup_opts
      )
    )
  end
end
