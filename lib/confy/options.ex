defmodule Confy.Options do
  require Confy
  @moduledoc """
  This struct represents the options you can pass
  to a call of `Confy.load/2` (or `YourModule.load/1`).

  Besides making it nice and explicit to have the options listed here,
  `Confy.Options` has itself been defined using `Confy.defconfig`,
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
end
