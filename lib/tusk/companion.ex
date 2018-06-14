defmodule Tusk.Companion do
  use GenServer, restart: :transient

  defstruct task: nil,
            supervisor: nil,
            timeout: 5000,
            timeout_ref: nil,
            on_success: nil,
            on_failure: nil,
            on_error: nil,
            reason: nil

  require Logger

  @spec start_link([Tusk.option()]) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  @impl GenServer
  def init(options) do
    {:ok, struct(__MODULE__, options)}
  end

  @impl GenServer
  def handle_call(:task, {pid, _ref}, %{timeout: timeout} = state) do
    Process.monitor(pid)

    case timeout do
      value when value in [:infinity, nil] ->
        {:reply, :ok, %{state | task: pid}}

      timeout when is_integer(timeout) ->
        ref = Process.send_after(self(), :timeout, timeout)
        {:reply, :ok, %{state | task: pid, timeout_ref: ref}}
    end
  end

  @impl GenServer
  def handle_call(:supervisor, {pid, _ref}, state) do
    Process.monitor(pid)
    {:reply, :ok, %{state | supervisor: pid}}
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
    {:noreply, cancel_timer(%{state | reason: error})}
  end

  @impl GenServer
  def handle_info(:timeout, %{task: pid, on_error: on_error} = state) do
    Process.exit(pid, :kill)

    Task.start(fn ->
      Tusk.execute(on_error, :timeout)
    end)

    {:noreply, %{state | timeout_ref: nil}}
  end

  defp cancel_timer(%{timeout_ref: nil} = state), do: state

  defp cancel_timer(%{timeout_ref: ref} = state) do
    Process.cancel_timer(ref)
    state
  end
end
