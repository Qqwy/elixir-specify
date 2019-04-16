defmodule Confy.Options do
  require Confy
  @moduledoc """
  This struct represents the options you can pass
  to a call of `Confy.load/2` (or `YourModule.load/1`).

  ### Metaconfiguration

  Besides making it nice and explicit to have the options listed here,
  `Confy.Options` has itself been defined using `Confy.defconfig/2`,
  which means that it (and thus what default options are passed on to to other Confy configurations)
  can be configured in the same way.

  """
  Confy.defconfig do
    @doc """
    A list of structures that implement the `Confy.Provider` protocol, which will be used to fetch configuration from.
    Later entries in the list take precedence over earlier entries.
    Defaults always have the lowest precedence, and `:overrides` always have the highest precedence.
    """
    field :sources, :term, default: []

    @doc """
    A list or map (or other enumerable) representing explicit overrides
    that are to be used instead of what can be found in the implicit sources stack.
    """
    field :overrides, :term, default: []

    @doc """
    The error to be raised if a missing field which is required has been encountered.
    """
    field :missing_fields_error, :term, default: Confy.MissingRequiredFieldsError

    @doc """
    The error to be raised if a field value could not properly be parsed.
    """
    field :parsing_error, :term, default: Confy.ParsingError

    @doc """
    When set to `true`, rather than returning the config struct,
    a map is returned with every field-key containing a list of consecutive found values.

    This is useful for debugging.
    """
    field :explain, :boolean, default: false
  end


  {line_number, existing_moduledoc} = Module.delete_attribute(__MODULE__, :moduledoc) || {0, ""}
  Module.put_attribute(__MODULE__, :moduledoc, {line_number, existing_moduledoc <>
    """
    ## Metaconfiguration Gotcha's

    Confy will only be able to find a source after it knows it exists.
    This means that it is impossible to define a different set of sources inside an external source.

    For this special case, Confy will look at the current process' Process dictionary,
    falling back to the Application environment (also known as the Mix environment),
    and finally falling back to an empty list of sources (its default).

    So, from lowest to highest precedence, option values are loaded in this order:

    1. Confy.Options default
    2. Application Environment `:confy`
    3. Process Dictionary `:confy` field
    4. Options passed to `Comfy.defconfig`
    5. Options passed to `YourModule.load`

    Requiring Confy to be configured in such a general way seems highly unlikely.
    If the current approach does turn out to not be good enough for your use-case,
    please open an issue on Confy's issue tracker.
    """
                                               })

end
