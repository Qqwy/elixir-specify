![](https://raw.githubusercontent.com/Qqwy/elixir_specify/master/brand/logo-text.png)

`Specify` is a library to create Comfortable, Explicit, Multi-Layered and Well-Documented Specifications for all your configurations, settings and options in Elixir.

[![hex.pm version](https://img.shields.io/hexpm/v/specify.svg)](https://hex.pm/packages/specify)
[![Build Status](https://travis-ci.org/Qqwy/elixir_confy.svg?branch=master)](https://travis-ci.org/Qqwy/elixir_confy)
[![Documentation](https://img.shields.io/badge/hexdocs-latest-blue.svg)](https://hexdocs.pm/specify/index.html)
[![Inline docs](http://inch-ci.org/github/qqwy/elixir_specify.svg)](http://inch-ci.org/github/qqwy/elixir_specify)

---

Basic features:

- Configuration is converted to a struct, with fields being parsed to their appropriate types.
- Specify a stack of sources to fetch the configuration from.
- Always possible to override local configuration using plain arguments to a function call.
- Fail-fast on missing or malformed values.
- Auto-generated documentation based on your config specification.

Specify can be used both to create normalized configuration structs during runtime and compile-time using both implicit external configuration sources and explicit arguments to a function call.

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


Basic usage is as follows, using `Specify.defconfig/1`:


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

and later `Specify.load/2`, `Specify.load_explicit/3` (or `YourModule.load/1`, `YourModule.load_explicit/2` which are automatically defined).
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

Notice that since the `:lullaby`-field is mandatory, if it is not defined in any of the configuration sources, an error will be thrown:

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

`Specify` comes with the following built-in providers:

- `Specify.Provider.MixEnv`, which uses `Mix.env` / `Application.get_env` to read from the application environment.
- `Specify.Provider.SystemEnv`, which uses `System.get_env` to read from system environment variables.
- `Specify.Provider.Process`, which uses `Process.get` to read from the current process' dictionary.

Often, Providers have sensible default values on how they work, making their usage simpler:
- `Specify.Provider.Process` will look at the configured `key`, but will default to the configuration specification module name.
- `Specify.Provider.MixEnv` will look at the configured `application_name` and `key`, but will default to the whole environment of an application (`Application.get_all_env`) if no key was set, with `application_name` defaulting to the configuration specification module name.
- `Specify.Provider.SystemEnv` will look at the configured `prefix` but will default to the module name (in all caps), followed by the field name (in all caps, separated by underscores). What names should be used for a field is also configurable.

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
- [x] Environment Variables (System.get_env) provider
- [x] Specify Provider Tests.
- [ ] Better/more examples
- [ ] Stable release

## Possibilities for the future

- (D)ETS provider
- CLI arguments provider, which could be helpful for defining e.g. Mix tasks.
- .env files provider.
- JSON and YML files provider.
- Nested configs?
- Possibility to load without raising on parsing falure (instead returning a success/failure tuple?)
- Watching for updates and call a configurable handler function when configuration has changed.

## Changelog

- 0.6 - Adds the `mfa` and `function` builtin parsers.
- 0.5 - Adds the `nonnegative_integer`, `positive_integer`, `nonnegative_float`, `positive_float` and `timeout` builtin parsers.
- 0.4.5 - Fixes built-in `integer` and `float` parsers to not crash on input like `"10a"` (but instead return `{:error, _}`).
- 0.4.4 - Fixes references to validation/parsing functions in documentation.
- 0.4.2 - Finishes provider tests; bugfix for the MixEnv provider.
- 0.4.1 - Improves documentation.
- 0.4.0 - Name change: from 'Confy' to 'Specify'. This name has been chosen to be more clear about the intent of the library.
- 0.3.0 - Changed `overrides:` to `explicit_values:` and added `Specify.load_explicit/3` function. (Also added tests and fixed parser bugs).
- 0.2.0 - Initially released version


## Attribution

I want to thank Chris Keathley for his interesting library [Vapor](https://github.com/keathley/vapor) which helped inspire Specify.

I also want to thank José Valim for the great conversations we've had about the advantages and disadvantages of various approaches to configuring Elixir applications.
