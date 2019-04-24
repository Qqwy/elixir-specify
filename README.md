# Specify

[![hex.pm version](https://img.shields.io/hexpm/v/specify.svg)](https://hex.pm/packages/specify)
[![Build Status](https://travis-ci.org/Qqwy/elixir_specify.svg?branch=master)](https://travis-ci.org/Qqwy/elixir_specify)
[![Inline docs](http://inch-ci.org/github/qqwy/elixir_specify.svg)](http://inch-ci.org/github/qqwy/elixir_specify)


Comfortable, Explicit, Multi-Layered and Well-Documented specifications for Dynamic Configuration in Elixir:

- Configuration is converted to a struct, with fields being parsed to their appropriate types.
- Specify a stack of sources to fetch the configuration from.
- Always possible to override local configuration using plain arguments to a function call.
- Fail-fast on missing or malformed values.
- Auto-generated documentation based on your config specification.


Configuration made with Specify is usually read _during runtime_ (like when starting a process) rather than during compile/boot-time. This is a contrast with how e.g. Mix configs or Distillery releases (on their own; they can be used in combination with Specify as well) work, since their configuration settings usually are fully set in stone already during compile-time.

## Installation

You can install Specify by adding `specify` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:specify, "~> 0.4.0"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/specify](https://hexdocs.pm/specify).

## Examples


Basic usage is as follows:


```elixir

defmodule Cosette.CastleOnACloud do
  require Specify
  Specify.defconfig do
    @doc "there are no floors for me to sweep"
    field :floors_to_sweep, :integer, default: 0

    @doc "there are a hundred boys and girls"
    field :amount_boys_and_girls, :integer, default: 100

    @doc "The lady all in white holds me and sings a lullaby"
    field :lullaby, :string

    @doc "Crying is usually not allowed"
    field :crying_allowed, :boolean, default: false
  end
end
```

```
iex> Cosette.CastleOnACloud.load(explicit_values: [lullaby: "I love you very much", crying_allowed: true])
%Cosette.CastleOnACloud{
  crying_allowed: true,
  floors_to_sweep: 0,
  lullaby: "I love you very much",
  amount_boys_and_girls: 100
}

```

### Mandatory Fields 

Notice that since the `;lullaby`-field is mandatory, if it is not defined in any of the configuration sources, an error will be thrown:

```elixir
Cosette.CastleOnACloud.load
** (Specify.MissingRequiredFieldsError) Missing required fields for `Elixir.Cosette.CastleOnACloud`: `:lullaby`.
    (specify) lib/specify.ex:179: Specify.prevent_missing_required_fields!/3
    (specify) lib/specify.ex:147: Specify.load/2
```

### Loading from Sources

Loading from another source is easy:

```elixir
iex> Application.put_env(Cosette.CastleOnACloud, :lullaby, "sleep little darling")
# or: in a Mix config.ex file
config Cosette.CastleOnACloud, lullaby: "sleep little darling"
```
```elixir
iex> Cosette.CastleOnACloud.load(sources: [Specify.Provider.MixEnv])
%Cosette.CastleOnACloud{
  crying_allowed: false,
  floors_to_sweep: 0,
  lullaby: "sleep little darling",
  no_boys_and_girls: 100
}
```

Rather than passing in the sources when loading the configuration, it often makes more sense to specify them when defining the configuration:

```elixir
defmodule Cosette.CastleOnACloud do
  require Specify
  Specify.defconfig sources: [Specify.Provider.MixEnv] do
    # ...
  end
end
```

## Providers

Providers can be specified by passing them to the `sources:` option (while loading the configuration structure or while defining it).
They can also be set globally by altering the `sources:` key of the `Specify` application environment, or per-process using the `:sources` subkey of the `Specify` key in the current process' dictionary (`Process.put_env`).

Be aware that for bootstrapping reasons, it is impossible to override the `:sources` field globally in an external source (because Specify would not know where to find it).

Most providers have sensible default values on how they work:
- `Specify.Provider.Process` will look at the configured `key`, but will default to the configuration specification module name.
- `Specify.Providers.MixEnv` will look at the configured `application_name` and `key`, but will default to the whole environment of an application (`Application.get_all_env`) if no key was set, with `application_name` defaulting to the configuration specification module name.

## Writing Providers

Providers implement the `Specify.Provider` protocol, which consists of only one function: `load/2`.
Its first argument is the implementation's own struct, the second argument being the configuration specification's module name.
If extra information is required about the configuration specification to write a good implementation, the Reflection function `module_name.__specify__`  can be used to look these up.


## Roadmap

- [x] Compound parsers for collections using `{collection_parser, element_parser}`-syntax, with provided `:list` parser.
- [x] Main functionality documentation.
- [x] Parsers documentation.
- [x] Writing basic Tests
  - [x] Specify.Parsers
  - [x] Main Specify module and functionality.
- [x] Thinking on how to handle environment variable names (capitalization, prefixes).
- [ ] (50%) Environment Variables (System.get_env) provider
- [ ] (33%) Specify Provider Tests.
- [ ] Better/more examples
- Stable release

## Possibilities for the future

- (D)ETS provider
- CLI arguments provider, which could be helpful for defining e.g. Mix tasks.
- .env files provider.
- JSON and YML files provider.
- Nested configs?
- Possibility to load without raising on parsing falure (instead returning a success/failure tuple?)
- Watching for updates and call a configurable handler function when configuration has changed.

## Changelog

- 0.3.0 - Changed `overrides:` to `explicit_values:` and added `Specify.load_explicit/3` function. (Also added tests and fixed parser bugs).
- 0.2.0 - Initially released version


## Attribution

I want to thank Chris Keathley for his interesting library [Vapor](https://github.com/keathley/vapor) which helped inspire Specify.
