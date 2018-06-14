defmodule Tusk do
  use GenServer, restart: :transient

  defstruct task: nil, companion: nil, no_retry_exceptions: []

  @type task :: {module, atom, [any]} | fun
  @type callback :: task
  @type option ::
          {:no_retry_exceptions, [module]}
          | {:on_success, callback}
          | {:on_failure, callback}
          | {:on_error, callback}
          | {:timeout, non_neg_integer | nil | :infinity}

  @doc """
  Starts a supervisor, a Tusk GenServer and a companion

  The supervisor and the companion are supervised by the dynamic supervisor,
  and the Tusk GenServer is supervised by the supervisor and monitored by the
  companion
  """
  @spec start(Supervisor.supervisor(), task, [option]) :: GenServer.on_start()
  def start(sup, task, options \\ []) do
    Tusk.DynamicSupervisor.start_child(sup, [task: task] ++ options)
  end

  @doc """
  execute an mfa or a closure
  """
  def execute(nil), do: nil

  def execute(task, result \\ nil)

  def execute(nil, _), do: nil

  def execute({m, f, a}, result) when is_atom(m) and is_atom(f) do
    apply(m, f, ((is_nil(result) && []) || [result]) ++ a)
  end

  def execute(func, result) when is_function(func) do
    case result do
      nil -> func.()
      result -> func.(result)
    end
  end

  @spec start_link([option]) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  @impl GenServer
  def init(options) do
    companion = Keyword.fetch!(options, :companion)
    GenServer.call(companion, :task)

    send(self(), :execute)
    {:ok, struct(__MODULE__, options)}
  end

  require Logger

  @impl GenServer
  def handle_info(:execute, %{companion: companion} = state) do
    try do
      result = execute(state.task)
      GenServer.call(companion, {:ok, result})

      Logger.debug("done")
      {:stop, :normal, state}
    rescue
      e ->
        if e.__struct__ in state.no_retry_exceptions do
          {:stop, {:shutdown, {:no_retry_exception, e}}, state}
        else
          stacktrace = System.stacktrace()
          reraise e, stacktrace
        end
    end
  end

  @impl GenServer
  def terminate(:normal, _state) do
    Logger.debug("Task finished")
  end

  @impl GenServer
  def terminate({:shutdown, {:no_retry_exception, error}}, %{companion: companion}) do
    GenServer.call(companion, {:error, {:no_retry_exception, error}})
    Logger.debug("exception but no retry")
  end

  @impl GenServer
  def terminate({_error, _stacktrace} = reason, _state) do
    Logger.debug(inspect(reason))
  end
end
