defmodule Tusk.Companion do
  use GenServer, restart: :transient

  defstruct [:task, :supervisor, :timeout, :on_success, :on_failure, :on_error, :reason]

  require Logger

  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  @impl GenServer
  def init(options) do
    {:ok, struct(__MODULE__, options)}
  end

  @impl GenServer
  def handle_call(:task, {pid, _ref}, state) do
    Process.monitor(pid)
    {:reply, :ok, Map.put(state, :task, pid)}
  end

  @impl GenServer
  def handle_call(:supervisor, {pid, _ref}, state) do
    Process.monitor(pid)
    {:reply, :ok, Map.put(state, :supervisor, pid)}
  end

  @impl GenServer
  def handle_call(
        {:ok, result},
        {pid, _ref},
        %{task: pid, supervisor: supervisor, on_success: on_success} = state
      ) do
    Task.start(fn ->
      Tusk.execute(on_success, result)
      Supervisor.stop(supervisor, :normal)
    end)

    {:stop, :normal, :ok, state}
  end

  @impl GenServer
  def handle_call(
        {:error, {:no_retry_exception, _error} = reason},
        {pid, _ref},
        %{task: pid, on_failure: on_failure} = state
      ) do
    Task.start(fn ->
      Tusk.execute(on_failure, reason)
    end)
    {:stop, :normal, :ok, state}
  end

  @impl GenServer
  def handle_info(
        {:DOWN, _ref, :process, supervisor, _reason},
        %{supervisor: supervisor, on_failure: on_failure, reason: reason} = state
      ) do
    Task.start(fn ->
      Tusk.execute(on_failure, {:exceeding_retry_limit, reason})
    end)
    Logger.debug("Supervisor is down")
    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info(
        {:DOWN, _ref, :process, task, {error, _stacktrace}},
        %{task: task, on_error: on_error} = state
      ) do
    Task.start(fn ->
      Tusk.execute(on_error, error)
    end)
    Logger.debug("Task process is down")
    {:noreply, %{state | reason: error}}
  end
end
