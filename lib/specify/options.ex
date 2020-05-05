defmodule Specify.Options do
  require Specify

  @moduledoc """
  This struct represents the options you can pass
  to a call of `Specify.load/2` (or `YourModule.load/1`).

  ### Metaconfiguration

  Besides making it nice and explicit to have the options listed here,
  `Specify.Options` has itself been defined using `Specify.defconfig/2`,
  which means that it (and thus what default options are passed on to to other Specify configurations)
  can be configured in the same way.

  """

  @doc false
  def list_of_sources(sources) do
    res =
      Enum.reduce_while(sources, [], fn
        source, acc ->
          case source do
            source = %struct_module{} ->
              Protocol.assert_impl!(Specify.Provider, struct_module)
              {:cont, [source | acc]}
            source when is_atom(source) ->
              parse_source_module(source, acc)
            {module, args} when is_atom(module) and is_map(args) ->
              source = struct(module, args)
              Protocol.assert_impl!(Specify.Provider, module)
              {:cont, [source | acc]}
            {module, fun, args} when is_atom(module) and is_atom(fun) and is_map(args) ->
              source = %struct_module{} = Kernel.apply(module, fun, args)
              Protocol.assert_impl!(Specify.Provider, struct_module)
              {:cont, [source | acc]}
          end
      end)

    case res do
      {:error, error} -> {:error, error}
      sources_list -> {:ok, Enum.reverse(sources_list)}
    end
  end

  defp parse_source_module(module, acc) do
    case module.__info__(:functions)[:new] do
      0 ->
        source = %struct_module{} = module.new()
        Protocol.assert_impl!(Specify.Provider, struct_module)
        {:cont, [source | acc]}

      _ ->
        {:halt,
         {:error,
          "`#{inspect(module)}` does not seem to have an appropriate default `new/0` function. Instead, pass a full-fledged struct (like `%#{inspect(module)}{}`), or one use one of the other ways to specify a source. \n\n(See the documentation of `Specify.Options.sources` for more information)"}}
    end
  end

  Specify.defconfig do
    @doc """
    A list of structures that implement the `Specify.Provider` protocol, which will be used to fetch configuration from.
    Later entries in the list take precedence over earlier entries.
    Defaults always have the lowest precedence, and `:explicit_values` always have the highest precedence.

    A source can be:
    - A struct. Example: `%Specify.Provider.SystemEnv{}`;
    - A module that has a `new/0`-method which returns a struct. Example: `Specify.Provider.SystemEnv`;
    - A tuple, whose first argument is a module and second argument is a map of arguments. This will be turned into a full-blown struct at startup using `Kernel.struct/2`. Example: `{Specify.Provider.SystemEnv, %{prefix: "CY", optional: true}}`;
    - A {module, function, arguments}-tuple, which will be called on startup. It should return a struct. Example: `{Specify.Provider.SystemEnv, :new, ["CY", [optional: true]]}`.

    In all cases, the struct should implement the `Specify.Provider` protocol (and this is enforced at startup).
    """
    field(:sources, &Specify.Options.list_of_sources/1, default: [])

    @doc """
    A list or map (or other enumerable) representing explicit values
    that are to be used instead of what can be found in the implicit sources stack.
    """
    field(:explicit_values, :term, default: [])

    @doc """
    The error to be raised if a missing field which is required has been encountered.
    """
    field(:missing_fields_error, :term, default: Specify.MissingRequiredFieldsError)

    @doc """
    The error to be raised if a field value could not properly be parsed.
    """
    field(:parsing_error, :term, default: Specify.ParsingError)

    @doc """
    When set to `true`, rather than returning the config struct,
    a map is returned with every field-key containing a list of consecutive found values.

    This is useful for debugging.
    """
    field(:explain, :boolean, default: false)
  end

  {line_number, existing_moduledoc} = Module.delete_attribute(__MODULE__, :moduledoc) || {0, ""}

  Module.put_attribute(
    __MODULE__,
    :moduledoc,
    {line_number,
     existing_moduledoc <>
       """
       ## Metaconfiguration Gotcha's

       Specify will only be able to find a source after it knows it exists.
       This means that it is impossible to define a different set of sources inside an external source.

       For this special case, Specify will look at the current process' Process dictionary,
       falling back to the Application environment (also known as the Mix environment),
       and finally falling back to an empty list of sources (its default).

       So, from lowest to highest precedence, option values are loaded in this order:

       1. Specify.Options default
       2. Application Environment `:specify`
       3. Process Dictionary `:specify` field
       4. Options passed to `Specify.defconfig`
       5. Options passed to `YourModule.load`

       Requiring Specify to be configured in such an even more general way seems highly unlikely.
       If the current approach does turn out to not be good enough for your use-case,
       please open an issue on Specify's issue tracker.
       """}
  )
end
