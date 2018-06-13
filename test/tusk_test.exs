defmodule TuskTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  defmodule Return do
    def result(x), do: x
  end

  describe "execute" do
    test "nil" do
      assert Tusk.execute(nil) == nil
    end

    test "nil nil" do
      assert Tusk.execute(nil, nil) == nil
    end

    test "mfa" do
      assert Tusk.execute({Return, :result, [123]}) == 123
    end

    test "mfa with extra" do
      assert Tusk.execute({Return, :result, []}, 123) == 123
    end

    test "function" do
      assert Tusk.execute(fn -> 123 end) == 123
    end

    test "function with extra" do
      assert Tusk.execute(fn x -> x end, 123) == 123
    end
  end

  defmodule TestException do
    defexception [:message]
  end

  defmodule ErrorTask do
    def test(pid, message \\ "test")

    def test(nil, message) do
      raise TestException, message: message
    end

    def test(pid, message) do
      send(pid, :up)
      Process.sleep(50)
      raise TestException, message: message
    end
  end

  defmodule GoodTask do
    def test(result) do
      Process.sleep(50)
      result
    end
  end

  defp assert_retry(message, times) do
    Process.sleep(50 * (times + 1))
    Enum.each(0..times, fn _ -> assert_receive ^message end)
    refute_receive ^message
  end

  describe "run" do
    setup do
      {:ok, pid} = Tusk.DynamicSupervisor.start_link()
      {:ok, %{sup: pid}}
    end

    test "retry once by default", %{sup: sup} do
      {:ok, _} = Tusk.start(sup, {ErrorTask, :test, [self()]})

      capture_log(fn ->
        assert_retry(:up, 1)
      end)
    end

    test "retry multiple times", %{sup: sup} do
      {:ok, _} = Tusk.start(sup, {ErrorTask, :test, [self()]}, max_restarts: 3)

      capture_log(fn ->
        assert_retry(:up, 3)
      end)
    end

    test "call on_success result", %{sup: sup} do
      this = self()
      on_success = fn result -> send(this, {:result, result}) end

      capture_log(fn ->
        {:ok, _} = Tusk.start(sup, {GoodTask, :test, [123]}, on_success: on_success)
        assert_receive {:result, 123}
      end)
    end

    test "not retry for no_retry_exceptions", %{sup: sup} do
      {:ok, _} =
        Tusk.start(
          sup,
          {ErrorTask, :test, [self()]},
          no_retry_exceptions: [TuskTest.TestException]
        )

      capture_log(fn ->
        assert_retry(:up, 0)
      end)
    end

    test "call on_failure when exceeding retry limit with the last error", %{sup: sup} do
      this = self()
      on_failure = fn error -> send(this, error) end

      capture_log(fn ->
        {:ok, _} = Tusk.start(sup, {ErrorTask, :test, [nil]}, on_failure: on_failure)
        assert_receive {:exceeding_retry_limit, %TuskTest.TestException{}}
      end)
    end

    test "call on_error when task errors", %{sup: sup} do
      this = self()
      on_error = fn error -> send(this, error) end

      capture_log(fn ->
        {:ok, _} = Tusk.start(sup, {ErrorTask, :test, [self()]}, on_error: on_error)
        assert_receive %TuskTest.TestException{}
      end)
    end

    test "timeout", %{sup: sup} do
      this = self()
      on_error = fn error -> send(this, error) end

      capture_log(fn ->
        {:ok, _} =
          Tusk.start(
            sup,
            {ErrorTask, :test, [self()]},
            on_error: on_error,
            timeout: 10
          )

        assert_receive :timeout
      end)
    end
  end
end
