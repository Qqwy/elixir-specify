# Confy

Explicit, multi-layered configuration in Elixir:

- Configuration is converted to a struct, with fields being parsed to their appropriate types.
- Specify a stack of sources to fetch the configuration from.
- Fail-fast on missing or malformed values.
- Auto-generated documentation based on your config specification.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `confy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:confy, "~> 0.1.0"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/confy](https://hexdocs.pm/confy).

## Possibilities for the future

- (D)ETS provider
- Environment Variables (System.get_env) provider
- CLI arguments provider, which could be helpful for defining e.g. Mix tasks.
- .env files provider.
- JSON and YML files provider.
- Watching for updates and call a configurable handler function when configuration has changed.
