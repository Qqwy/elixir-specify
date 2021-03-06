defmodule Specify do
  @moduledoc """
  Specify allows you to make your configuration explicit:

  - Specify exactly what fields are expected.
  - Specify exactly what values these fields might take, by giving them parser-functions.
  - Load their values from a slew of different locations, with 'explicitly passed in to the function' as final option.
  """

  defmodule MissingRequiredFieldsError do
    @moduledoc """
    Default exception to be raised when a required field is not existent in any configuration source.
    """
    defexception [:message]
  end

  defmodule ParsingError do
    @moduledoc """
    Default exception to be raised when it is impossible to parse one of the configuration values.

    (See also `Specify.Parsers`)
    """
    defexception [:message]
  end

  defmodule Schema do
    @moduledoc """
    Functions that can be used inside `Specify.defconfig/2`.
    """

    @doc """
    Specifies a field that is part of the configuration struct.

    Can/should only be called inside a call to `Specify.defconfig`.

    - `name` should be an atom representing the field. It will also become the field name for the struct that is created.
    - `parser` should either be:
      - an arity-one function capture like `&YourModule.some_type_parser/1`.
      - An atom representing one of the common parser function names in `Specify.Parsers` like `:integer`, `:string`, `:boolean` or `:term`.
      - A two-element tuple like `{:list, :atom}`. The first element represents the 'collection parser' which is an arity-2 function that takes the 'element parser' as second argument. The second element is the 'element parser'. Both of the elements listed in the tuple can also be either an atom, or a function capture with the correct arity. (like `{&YourAwesomeModule.fancy_collection/2, :integer}`).

    `parser` defaults to `:string`.

    Supported field options are:

    - `default:`, supplies a default value to this field. If not set, the configuration field is set to be _required_.

    You are highly encouraged to add a `@doc`umentation text above each and every field;
    these will be added to the configuration's module documentation.
    """
    defmacro field(name, parser \\ :string, options \\ []) do
      quote do
        field_documentation = Module.delete_attribute(__MODULE__, :doc)

        field_documentation =
          case field_documentation do
            {_line, val} ->
              val

            nil ->
              IO.warn(
                "Missing documentation for configuration field `#{unquote(name)}`. Please add it by adding `@doc \"field documentation here\"` above the line where you define it."
              )

              ""
          end

        Specify.__field__(
          __MODULE__,
          unquote(name),
          unquote(parser),
          field_documentation,
          unquote(options)
        )
      end
    end
  end

  @doc """
  Defines a configuration structure in the current module.

  Fields are added to this configuration structure by calling `Specify.Schema.field/3`
  (which can be called just as `field` because `Specify.Schema` is autoamatically imported into the
  inner context of the call to `defconfig`.)

  The `options` that can be passed to this module are used as defaults for the options passed to a call to `Specify.load/2` or `YourModule.load/1`.

  See also `Specify.Schema.field/3` and `Specify.Options`

  ## Reflection

  The special function `__specify__/1` will be defined on the module as well. It is not intended to be used
  by people that want to consume your configuration,
  but it is there to e.g. allow `Specify.Provider` implementations to be smarter
  in how they fetch the configuration for the module. For instance, configuration
  might be lazily fetched, when knowing what field names exist beforehand.

  `YourModule.__specify__/1` supports the following publicly usable parameters:

  - `__specify__(:field_names)` returns a MapSet of atoms, one per field in the configuration structure.
  - `__specify__(:defaults)` returns a Map containing only the `field_name => value`s of field names having default values.
  - `__specify__(:requireds)` returns a MapSet of atoms, one per required field in the configuration structure.
  - `__specify__(:parsers)` returns a Map of the format `field_name => parser`.
  - `__specify__(:field_options)` returns a Map of the format `field_name => options`, where `options` is the keyword-list that was passed to the `field` macro.
  """
  defmacro defconfig(options \\ [], do: block) do
    quote do
      import Specify.Schema
      Module.register_attribute(__MODULE__, :config_fields, accumulate: true)

      try do
        unquote(block)
      after
        config_fields =
          Module.get_attribute(__MODULE__, :config_fields)
          |> Enum.reverse()

        {line_number, existing_moduledoc} =
          Module.delete_attribute(__MODULE__, :moduledoc) || {0, ""}

        Module.put_attribute(
          __MODULE__,
          :moduledoc,
          {line_number, existing_moduledoc <> Specify.__config_doc__(config_fields)}
        )

        defstruct(Specify.__struct_fields__(config_fields))

        # Reflection; part of 'public API' for Config Providers,
        # but not of public API for consumers of '__MODULE__'.
        @field_names Specify.__field_names__(config_fields)
        @field_options Specify.__field_options__(config_fields)
        @defaults Specify.__defaults__(config_fields)
        @required_fields Specify.__required_fields__(config_fields)
        @parsers Specify.__parsers__(config_fields)

        # Super secret private reflection; doing this at compile-time speeds up `load`.
        @la_defaults for {name, val} <- @defaults, into: %{}, do: {name, [val]}
        @la_requireds for name <- @required_fields, into: %{}, do: {name, []}
        @loading_accumulator Map.merge(@la_defaults, @la_requireds)

        @doc false
        def __specify__(:field_names), do: @field_names
        def __specify__(:field_options), do: @field_options
        def __specify__(:defaults), do: @defaults
        def __specify__(:required_fields), do: @required_fields
        def __specify__(:parsers), do: @parsers
        def __specify__(:__loading_begin_accumulator__), do: @loading_accumulator

        @doc """
        Loads, parses, and normalizes the configuration of `#{inspect(__MODULE__)}`, based on the current source settings, returning the result as a struct.

        For more information about the options this function supports, see
        `Specify.load/2` and `Specify.Options`
        """
        def load(options \\ []), do: Specify.load(__MODULE__, options ++ unquote(options))

        @doc """
        Loads, parses and normalizes the configuration of `#{inspect(__MODULE__)}`, using the provided `explicit_values` (and falling back to values configured elsewhere)

        For more information about the options this function supports, see
        `Specify.load_explicit/3` and `Specify.Options`
        """
        def load_explicit(explicit_values, options \\ []),
          do: Specify.load_explicit(__MODULE__, explicit_values, options ++ unquote(options))

        :ok
      end
    end
  end

  @doc """
  Loads, parses, and normalizes the configuration of `config_module`, based on the current source settings, returning the result as a struct.

  (This is the more general way of calling `config_module.load/1`).

  See `Specify.Options` for more information of the options that can be supplied to this function,
  and how it can be configured further.
  """
  def load(config_module, options \\ []) do
    explicit_values =
      (options[:explicit_values] || [])
      |> Enum.to_list()

    prevent_improper_explicit_values!(config_module, explicit_values)

    options = parse_options(config_module, options)

    # Values explicitly passed in are always the last, highest priority source.
    sources = options.sources ++ [explicit_values]
    sources_configs = load_sources_configs(config_module, sources)

    if options.explain do
      sources_configs
    else
      prevent_missing_required_fields!(config_module, sources_configs, options)

      parsers = config_module.__specify__(:parsers)

      sources_configs
      |> Enum.map(&try_load_and_parse!(&1, parsers, config_module, options))
      |> (fn config -> struct(config_module, config) end).()
    end
  end

  @doc """
  Loads, parses and normalizes the configuration of `config_module`, using the provided `explicit_values` (and falling back to values configured elsewhere)

  This call is conceptually the same as `Specify.load(config_module, [explicit_values: [] | options])`, but makes it more explicit that values
  are meant to be passed in as arguments.

  Prefer this function if you do not intend to use Specify's 'cascading configuration' functionality, such as when e.g. just parsing options passed to a function,
  `use`-statement or other macro.
  """
  def load_explicit(config_module, explicit_values, options \\ []) do
    full_options = put_in(options, [:explicit_values], explicit_values)
    load(config_module, full_options)
  end

  # Raises if `explicit_values` contains keys that are not part of the configuration structure of `config_module`.
  defp prevent_improper_explicit_values!(config_module, explicit_values) do
    improper_explicit_values =
      explicit_values
      |> Keyword.keys()
      |> MapSet.new()
      |> MapSet.difference(config_module.__specify__(:field_names))

    if(Enum.any?(improper_explicit_values)) do
      raise ArgumentError,
            "The following fields passed as `:explicit_values` are not part of `#{
              inspect(config_module)
            }`'s fields: `#{improper_explicit_values |> Enum.map(&inspect/1) |> Enum.join(", ")}`."
    end
  end

  # Raises appropriate error if required fields of `config_module` are missing in `sources_configs`.
  defp prevent_missing_required_fields!(config_module, sources_configs, options) do
    missing_required_fields =
      sources_configs
      |> Enum.filter(fn {_key, value} -> value == [] end)
      |> Enum.into(%{})

    if Enum.any?(missing_required_fields) do
      field_names = Map.keys(missing_required_fields)

      raise options.missing_fields_error,
            "Missing required fields for `#{config_module}`: `#{
              field_names |> Enum.map(&inspect/1) |> Enum.join(", ")
            }`."
    end
  end

  # Loads the listed `sources` in turn, warning for missing ones.
  defp load_sources_configs(config_module, sources) do
    sources
    |> Enum.map(&load_source(&1, config_module))
    |> reject_and_warn_unloadable_sources(config_module)
    |> list_of_configs2config_of_lists(config_module)
  end

  # Attempts to parse the highest-priority value of a given `name`.
  # Upon failure, raises an appropriate error.
  defp try_load_and_parse!({name, values}, parsers, config_module, options) do
    parser = construct_parser(parsers[name])

    case parser.(hd(values)) do
      {:ok, value} ->
        {name, value}

      {:error, reason} ->
        raise options.parsing_error,
              reason <>
                " (required for loading the field `#{inspect(name)}` of `#{inspect(config_module)}`)"

      other ->
        raise ArgumentError,
              "Improper Specify configuration parser result. Parser `#{inspect(parsers[name])}` is supposed to return either {:ok, val} or {:error, reason} but instead, `#{
                inspect(other)
              }` was returned."
    end
  end

  defp construct_parser(parser_list) when is_list(parser_list) do
    parser_funs = Enum.map(parser_list, &construct_parser(&1))

    fn thing -> Enum.find_value(
        parser_funs,
        {:error, "No validating parser found"},
        fn parser_fun ->
          case parser_fun.(thing) do
            {:ok, val} ->
              {:ok, val}

            {:error, _} ->
              nil
          end
        end
      )
    end
  end

  defp construct_parser({collection_parser, elem_parser}) do
    fn thing -> collection_parser.(thing, elem_parser) end
  end

  defp construct_parser(elem_parser) do
    elem_parser
  end

  # Parses `options` into a normalized `Specify.Options` struct.
  defp parse_options(config_module, options)
  # Catch bootstrapping-case
  defp parse_options(Specify.Options, options) do
    %{
      __struct__: Specify.Options,
      sources:
        options[:sources] ||
          Process.get(:specify, [])[:sources] ||
          Application.get_env(Specify, :sources) ||
          [],
      missing_fields_error:
        options[:missing_fields_error] ||
          Process.get(Specify, [])[:missing_fields_error] ||
          Application.get_env(Specify, :missing_fields_error) ||
          Specify.MissingRequiredFieldsError,
      parsing_error:
        options[:parsing_error] ||
          Process.get(Specify, [])[:parsing_error] ||
          Application.get_env(Specify, :parsing_error) ||
          Specify.ParsingError,
      explain:
        options[:explain] ||
          false
    }
  end

  defp parse_options(_config_module, options), do: Specify.Options.load(explicit_values: options)

  # Turns a list of Access-implementations into a map of lists.
  # In the end, empty values will look like `key: []`.
  # And filled ones like `key: [something | ...]`
  defp list_of_configs2config_of_lists(list_of_configs, config_module) do
    begin_accumulator = config_module.__specify__(:__loading_begin_accumulator__)

    list_of_configs
    |> Enum.reduce(begin_accumulator, fn config, acc ->
      :maps.map(
        fn key, values_list ->
          case Access.fetch(config, key) do
            {:ok, val} -> [val | values_list]
            :error -> values_list
          end
        end,
        acc
      )
    end)
  end

  defp load_source(source, config_module) do
    {source, Specify.Provider.load(source, config_module)}
  end

  # Logs errors on sources that cannot be found,
  # and transforms `{source, {:ok, config}} -> config` for all successful configurations.
  defp reject_and_warn_unloadable_sources(sources_configs, config_module) do
    require Logger

    sources_configs
    |> Enum.flat_map(fn
      {_source, {:ok, config}} ->
        [config]

      {source, {:error, error}} ->
        case error do
          :not_found ->
            Logger.warn("""
            While loading the configuration `#{inspect(config_module)}`, the source `#{
              inspect(source)
            }` could not be found.
            Please make sure it exists.
            In the case you do not need this source, consider removing this source from the `sources:` list.
            """)

          :malformed ->
            Logger.warn("""
            While loading the configuration `#{inspect(config_module)}`, found out that
            it was not possible to parse the configuration inside #{inspect(source)}.
            This usually indicates a grave problem!
            """)
        end

        []
    end)
  end

  @doc false
  # Handles the actual work of the `field` macro.
  def __field__(module, name, parser, field_documentation, options) do
    normalized_parser = normalize_parser(parser)

    Module.put_attribute(module, :config_fields, %{
      name: name,
      parser: normalized_parser,
      original_parser: parser,
      documentation: field_documentation,
      options: options
    })
  end

  # Extracts the struct definition keyword list
  # from the outputs of the list of `field` calls.
  @doc false
  def __struct_fields__(config_fields) do
    config_fields
    |> Enum.map(fn %{name: name, options: options} ->
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
      |> Enum.reduce("", fn %{
                              name: name,
                              parser: parser,
                              original_parser: original_parser,
                              documentation: documentation,
                              options: options
                            },
                            acc ->
        doc = """

        ### #{name}

        #{documentation}

        #{parser_doc(parser, original_parser)}
        """

        doc =
          case Access.fetch(options, :default) do
            {:ok, val} ->
              """
              #{doc}
              Defaults to#{clever_prettyprint(val)}
              """

            :error ->
              """
              #{doc}
              Required field.
              """
          end

        acc <> doc
      end)

    """
    ## Configuration structure documentation:

    This configuration was made using the `Specify` library.
    It contains the following fields:

    #{acc}
    """
  end

  # Render a multiline Markdown code block if `value` is large enough
  # to be pretty-printed across multiple lines.
  # otherwise, render an inline Markdown code block.
  # Functions are an exception: there are always on their own line to
  # make then clickable.
  defp clever_prettyprint(f) when is_function(f) do
    "&" <> f_str = inspect(f)

    "`#{f_str}`."
  end

  defp clever_prettyprint(value) do
    inspected = Kernel.inspect(value, printable_limit: :infinity, limit: :infinity, width: 80, pretty: true)
    if String.contains?(inspected, "\n") do
      """
      :
      ```
      #{inspected}
      ```
      """
    else
      " `#{inspected}`."
    end
  end

  defp parser_doc(parser, original_parser) do
    case original_parser do
      atom when is_atom(atom) ->
        """
        Validated/parsed by calling `#{Macro.to_string(parser) |> String.trim_leading("&")}`.

        (Specified as `#{inspect(atom)}`)
        """

      {collection_parser, parser} ->
        """
        Validated/parsed by calling `fn thing -> (#{
          Macro.to_string(normalize_parser(collection_parser, 2)) |> String.trim_leading("&")
        }).(thing, #{Macro.to_string(normalize_parser(parser))}) end`.

        (Specified as `{#{Macro.to_string(collection_parser)}, #{Macro.to_string(parser)}}`)
        """

      _other ->
        """
        Validated/parsed by calling `#{Macro.to_string(parser) |> String.trim_leading("&")}`.
        """
    end
  end

  @doc false
  # Builds a map of fields with default values.
  def __defaults__(config_fields) do
    config_fields
    |> Enum.filter(fn %{options: options} ->
      case Access.fetch(options, :default) do
        {:ok, _} -> true
        :error -> false
      end
    end)
    |> Enum.map(fn %{name: name, options: options} ->
      {name, options[:default]}
    end)
    |> Enum.into(%{})
  end

  @doc false
  # Builds a MapSet of all the required fields
  def __required_fields__(config_fields) do
    config_fields
    |> Enum.filter(fn %{options: options} ->
      case Access.fetch(options, :default) do
        :error -> true
        _ -> false
      end
    end)
    |> Enum.map(fn %{name: name} ->
      name
    end)
    |> MapSet.new()
  end

  @doc false
  # Builds a MapSet of all the fields
  def __field_names__(config_fields) do
    config_fields
    |> Enum.map(fn %{name: name} -> name end)
    |> MapSet.new()
  end

  @doc false
  # Builds a MapSet of all the fields
  def __field_options__(config_fields) do
    config_fields
    |> Enum.map(fn %{name: name, options: options} -> {name, options} end)
    |> Enum.into(%{})
  end

  @doc false
  # Builds a map of parsers for the fields.
  def __parsers__(config_fields) do
    config_fields
    |> Enum.map(fn %{name: name, parser: parser} ->
      {name, parser}
    end)
    |> Enum.into(%{})
  end

  # Replaces simplified atom parsers with
  # an actual reference to the parser function in `Specify.Parsers`.
  defp normalize_parser(parser, arity \\ 1)

  defp normalize_parser(parsers, _arity) when is_list(parsers) do
    Enum.map(parsers, &normalize_parser(&1))
  end

  defp normalize_parser(parser, arity) when is_atom(parser) do
    case Specify.Parsers.__info__(:functions)[parser] do
      nil ->
        raise ArgumentError,
              "Parser shorthand `#{inspect(parser)}` was not recognized. Only atoms representing names of functions that live in `Specify.Parsers` are."

      ^arity ->
        Function.capture(Specify.Parsers, parser, arity)
    end
  end

  defp normalize_parser({collection_parser, elem_parser}, _arity) do
    {normalize_parser(collection_parser, 2), normalize_parser(elem_parser, 1)}
  end

  defp normalize_parser(other, _arity), do: other
end
