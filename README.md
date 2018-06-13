# Tusk

Elixir task library with retry, success/failure callback and timeout

**Built on top of supervisors**

## Installation

The package can be installed by adding `tusk` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tusk, "~> 0.1.0"}
  ]
end
```

## Usage

- Add Tusk.DynamicSupervisor to your supervision tree
- `Tusk.run(sup, task, options)`
  - where `sup` is the dynamic supervisor
  - `task` can be an `{m, f, a}` tuple or a closure (anonymous function)
- Available options
  - `timeout:` integer, `:infinity` or `nil`
    - both `:infinity` and `nil` disable timeout
  - `callbacks:`
    - `on_success:` mfa or closure
    - `on_failure:` mfa or closure
    - `on_error:` mfa or closure
    - on_success gets called with the task result
    - on_failure is called once after no more retries
    - on_error is called every time an error occurs
    - on_failure and on_error get called with an error
  - `no_retry_exceptions:`
    - a list of Exception names that if seen, give up retrying
