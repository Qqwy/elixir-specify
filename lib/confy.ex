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


  defmacro defconfig(do: block) do
    quote do
      import Confy.Schema
      Module.register_attribute(__MODULE__, :config_fields, accumulate: true)
      try do
        unquote(block)
      after
        config_fields = Module.get_attribute(__MODULE__, :config_fields) |> Enum.reverse
        existing_moduledoc = Module.delete_attribute(__MODULE__, :moduledoc) || ""
        line_number = 0
        Module.put_attribute(__MODULE__, :moduledoc, {line_number, existing_moduledoc <> Confy.__config_doc__(config_fields)})

        defstruct(Confy.__struct_fields__(config_fields))
        @defaults Confy.__defaults__(config_fields)
        def __defaults__(), do: @defaults

        @required_fields Confy.__required_fields__(config_fields)
        def __required_fields__(), do: @required_fields

        @parsers Confy.__parsers__(config_fields)
        def __parsers__(), do: @parsers

        def load(options \\ []), do: Confy.load(__MODULE__, options)

        :ok
      end
    end
  end

  def load(config_module, options \\ []) do
    # TODO fetch from other source
    # TODO parse `options`.
    overrides = options[:overrides] || []
    options = parse_options(config_module, options)

    # Values explicitly passed in are always the last, highest priority source.
    sources = options.sources ++ [overrides]

    defaults = for {name, val} <- config_module.__defaults__, into: %{}, do: {name, [val]}
    requireds = for name <- config_module.__required_fields__, into: %{}, do: {name, []}
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
        # TODO raise on failure to parse
        parsers = config_module.__parsers__()
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
          Application.get_env(:confy, :sources) ||
          [],

      missing_fields_error:
        options[:missing_fields_error] ||
          Application.get_env(:confy, :missing_fields_error) ||
          Confy.MissingRequiredFieldsError,

      parsing_error:
        options[:parsing_error] ||
          Application.get_env(:confy, :parsing_error) ||
          Confy.ParsingError,
      explain:
        options[:explain] ||
        false
    }
  end
  defp parse_options(config_module, options) do
    Confy.Options.load(options)
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

          #### #{name}

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
    ### Configuration structure documentation:

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
