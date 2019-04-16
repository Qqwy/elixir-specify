defmodule Confy do
  @moduledoc """
  Confy allows you to make your configuration explicit:

  - Specify exactly what fields are expected.
  - Specify exactly what values these fields might take, by giving them parser-functions.
  - Load their values from a slew of different locations, with 'explicitly passed in to the function' as final option.
  """

  defmodule MissingRequiredFieldsError do
    defexception [:message]
  end

  defmodule Schema do
    @doc """
    Specifies a field that is part of the configuration struct.

    Can/should only be called inside a call to `Confy.defconfig`.


    Supported options are:

    - `default:`, supplies a default value to this field. If not set, the configuration field is set to be _required_.

    You are highly encouraged to add a `@doc`umentation text above each and every field;
    these will be added to the configuration's module documentation.
    """
    defmacro field(name, parser, opts \\ []) do
      quote do
        field_documentation = Module.delete_attribute(__MODULE__, :doc)
        field_documentation =
          case field_documentation do
            {_line, val} -> val
            nil ->
              IO.warn("Missing documentation for configuration field `#{unquote(name)}`. Please add it by adding `@doc \"field documentation here\"` above the line where you define it.")
              ""
          end
        Confy.__field__(__MODULE__, unquote(name), unquote(parser), field_documentation, unquote(opts))
      end
    end
  end


  @doc """
  Defines a configuration structure in the current module.

  Fields are added to this configuration structure by calling `Confy.Schema.field/3`
  (which can be called just as `field` because `Confy.Schema` is autoamatically imported into the
  inner context of the call to `defconfig`.)

  The `options` that can be passed to this module are used as defaults for the options passed to a call to `Confy.load/2` or `YourModule.load/1`.

  See also `Confy.Schema.field/3` and `Confy.Options`

  ## Reflection

  The special function `__confy__/1` will be defined on the module as well. It is not intended to be used
  by people that want to consume your configuration,
  but it is there to e.g. allow `Confy.Provider` implementations to be smarter
  in how they fetch the configuration for the module. For instance, configuration
  might be lazily fetched, when knowing what field names exist beforehand.

  `YourModule.__confy__/1` supports the following parameters:

  - `__confy__(:field_names)` returns a MapSet of atoms, one per field in the configuration structure.
  - `__confy__(:defaults)` returns a Map containing only the `field_name => value`s of field names having default values.
  - `__confy__(:requireds)` returns a MapSet of atoms, one per required field in the configuration structure.
  - `__confy__(:parsers)` returns a Map of the format `field_name => parser`.
  """
  defmacro defconfig(options \\ [], do: block) do
    quote do
      import Confy.Schema
      Module.register_attribute(__MODULE__, :config_fields, accumulate: true)
      try do
        unquote(block)
      after
        config_fields = Module.get_attribute(__MODULE__, :config_fields) |> Enum.reverse
        {line_number, existing_moduledoc} = Module.delete_attribute(__MODULE__, :moduledoc) || {0, ""}
        Module.put_attribute(__MODULE__, :moduledoc, {line_number, existing_moduledoc <> Confy.__config_doc__(config_fields)})

        defstruct(Confy.__struct_fields__(config_fields))

        @field_names Confy.__field_names__(config_fields)
        @defaults Confy.__defaults__(config_fields)
        @required_fields Confy.__required_fields__(config_fields)
        @parsers Confy.__parsers__(config_fields)
        @doc false
        # Reflection; part of 'public API' for Config Providers,
        # but not of public API for consumers of '__MODULE__'.
        def __confy__(:field_names), do: @field_names
        def __confy__(:defaults), do: @defaults
        def __confy__(:required_fields), do: @required_fields
        def __confy__(:parsers), do: @parsers

        @doc """
        Loads, parses, and normalizes the configuration of `#{inspect(__MODULE__)}`, based on the current source settings, returning the result as a struct.

        For more information about the options this function supports, see
        `Confy.load/2` and `Confy.Options`
        """
        def load(options \\ []), do: Confy.load(__MODULE__, options ++ unquote(options))

        :ok
      end
    end
  end

  @doc """
  Loads, parses, and normalizes the configuration of `config_module`, based on the current source settings, returning the result as a struct.

  (This is the more general way of calling `config_module.load/1`).

  See `Confy.Options` for more information of the options that can be supplied to this function,
  and how it can be configured further.
  """
  def load(config_module, options \\ []) do
    overrides = (options[:overrides] || []) |> Enum.to_list
    options = parse_options(config_module, options)

    improper_overrides = MapSet.difference(MapSet.new(Keyword.keys(overrides)), config_module.__confy__(:field_names))

    if(Enum.any?(improper_overrides)) do
      raise ArgumentError, "The following fields passed as `:overrides` are not part of `#{inspect(config_module)}`'s fields: `#{improper_overrides |> Enum.map(&inspect/1) |> Enum.join(", ")}`."
    end

    # Values explicitly passed in are always the last, highest priority source.
    sources = options.sources ++ [overrides]

    defaults = for {name, val} <- config_module.__confy__(:defaults), into: %{}, do: {name, [val]}
    requireds = for name <- config_module.__confy__(:required_fields), into: %{}, do: {name, []}
    begin_accumulator = Map.merge(defaults, requireds)

    sources_configs =
      sources
      |> Enum.map(&load_source(&1, config_module))
      |> fn sources_configs_tuples -> reject_and_warn_unloadable_sources(config_module, sources_configs_tuples) end.()
      |> fn sources_configs -> list_of_configs2config_of_lists(begin_accumulator, sources_configs) end.()

    if options.explain do
      sources_configs
    else
      missing_required_fields =
        sources_configs
        |> Enum.filter(fn {key, value} -> value == [] end)
        |> Enum.into(%{})

      if Enum.any?(missing_required_fields) do
        field_names = Map.keys(missing_required_fields)
        raise options.missing_fields_error, "Missing required fields for `#{config_module}`: `#{field_names |> Enum.map(&inspect/1) |> Enum.join(", ")}`."
      else
        parsers = config_module.__confy__(:parsers)
        sources_configs
        |> Enum.map(fn {name, values} ->
          case parsers[name].(hd(values)) do
            {:ok, value} -> {name, value}
            {:error, reason} -> raise options.parsing_error, reason
            other ->
              raise ArgumentError, "Improper Confy configuration parser result. Parser `#{parsers[name]}` is supposed to return either {:ok, val} or {:error, reason} but instead, `#{inspect(other)}` was returned."
          end
        end)
        |> fn config -> struct(config_module, config) end.()
      end
    end
  end

  # Catch bootstrapping-case
  defp parse_options(Confy.Options, options) do
    %{
      __struct__:
        Confy.Options,
      sources:
        options[:sources] ||
        Process.get(:confy, [])[:sources] ||
        Application.get_env(:confy, :sources) ||
        [],

      missing_fields_error:
        options[:missing_fields_error] ||
        Process.get(:confy, [])[:missing_fields_error] ||
        Application.get_env(:confy, :missing_fields_error) ||
        Confy.MissingRequiredFieldsError,

      parsing_error:
        options[:parsing_error] ||
        Process.get(:confy, [])[:parsing_error] ||
        Application.get_env(:confy, :parsing_error) ||
        Confy.ParsingError,
      explain:
        options[:explain] ||
        false
    }
  end
  defp parse_options(config_module, options) do
    Confy.Options.load(overrides: options)
  end

  defp list_of_configs2config_of_lists(defaults, list_of_configs) do
    list_of_configs
    |> Enum.reduce(defaults, fn config, acc ->
      :maps.map(fn key, values_list ->
        case Access.fetch(config, key) do
          {:ok, val} -> [val | values_list]
          :error -> values_list
        end
      end, acc)
    end)
  end

  defp load_source(source, config_module) do
    {source, Confy.Provider.load(source, config_module)}
  end

  defp reject_and_warn_unloadable_sources(config_module, sources_configs) do
    require Logger
    sources_configs
    |> Enum.flat_map(fn
      {_source, {:ok, config}} -> [config]
      {source, {:error, error}} ->
        case error do
          :not_found ->
            Logger.error("""
            While loading the configuration `#{inspect(config_module)}`, the source `#{inspect(source)}` could not be found.
            Please make sure it exists.
            In the case you do not need this source, consider removing this source from the `sources:` list.
            """)
          :malformed ->
            Logger.error("""
            While loading the configuration `#{inspect(config_module)}`, found out that
            it was not possible to parse the configuration inside #{inspect(source)}.
            This usually indicates a grave problem!
            """)
        end
        []
    end)
  end


  @doc false
  def __field__(module, name, parser, field_documentation, options) do
    parser = normalize_parser(parser)
    Module.put_attribute(module, :config_fields, {name, parser, field_documentation, options})
  end

  # Extracts the struct definition keyword list
  # from the outputs of the list of `field` calls.
  @doc false
  def __struct_fields__(config_fields) do
    config_fields
    |> Enum.map(fn {name, parser, documentation, options} ->
      {name, options[:default]}
    end)
  end

  @doc false
  # Builds the module documentation
  # for the configuration.
  # This includes information on each of the fields,
  # with the user-supplied documentation description,
  # as well as the used parser and potential default value.
  def __config_doc__(config_fields) do
    acc =
      config_fields
      |> Enum.reduce("", fn {name, parser, documentation, options}, acc ->
          doc = """

          ### #{name}

          #{documentation || "ASDF"}

          Validated/parsed by calling `#{Macro.to_string(parser)}`.
          """

          doc =
            case Access.fetch(options, :default) do
              {:ok, val} -> """
                #{doc}
                Defaults to `#{inspect(val)}`.
                """
              :error -> """
                #{doc}
                Required field.
                """
          end

          acc <> doc
        end)

    """
    ## Configuration structure documentation:

    This configuration was made using the `Confy` library.
    It contains the following fields:

    #{acc}
    """
  end

  @doc false
  # Builds a map of fields with default values.
  def __defaults__(config_fields) do
    config_fields
    |> Enum.filter(fn {name, _parser, _documentation, options} ->
      case Access.fetch(options, :default) do
        {:ok, _} -> true
        :error -> false
      end
    end)
    |> Enum.map(fn {name, parser, _documentation, options} ->
      {name, options[:default]}
    end)
    |> Enum.into(%{})
  end

  @doc false
  # Builds a MapSet of all the required fields
  def __required_fields__(config_fields) do
    config_fields
    |> Enum.filter(fn {name, _parser, _documentation, options} ->
      case Access.fetch(options, :default) do
        :error -> true
        _ -> false
      end
    end)
    |> Enum.map(fn {name, _, _, _} ->
      name
    end)
    |> MapSet.new()
  end

  @doc false
  def __field_names__(config_fields) do
    config_fields
    |> Enum.map(fn {name, _, _, _} -> name end)
    |> MapSet.new()
  end

  @doc false
  # Builds a map of parsers for the fields.
  def __parsers__(config_fields) do
    config_fields
    |> Enum.map(fn {name, parser, _, _} ->
      {name, parser}
    end)
    |> Enum.into(%{})
  end


  # Replaces simplified atom parsers with
  # an actual reference to the parser function in `Confy.Parsers`.
  # NOTE: I dislke the necessity of `Code.eval_quoted` here, but do not currently know of another way.
  defp normalize_parser(parser) when is_atom(parser) do
    case Confy.Parsers.__info__(:functions)[parser] do
      nil -> raise ArgumentError, "Parser shorthand `#{inspect(parser)}` was not recognized. Only atoms representing names of functions that live in `Confy.Parsers` are."
      1 ->
        {binding, []} = Code.eval_quoted(quote do &Confy.Parsers.unquote(parser)/1 end)
        binding
    end
  end
  defp normalize_parser(other), do: other
end
