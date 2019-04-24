defprotocol Specify.Provider do
  @moduledoc """
  Protocol to load configuration from a signle source.

  Configuration Providers implement this protocol, which consists of only one function: `load/2`.
  """

  @doc """
  Loads the configuration of specification `module` from the source indicated by `struct`.

  Its first argument is the implementation's own struct, the second argument being the configuration specification's module name.
  If extra information is required about the configuration specification to write a good implementation, the Reflection function `module_name.__specify__`  can be used to look these up.

  See also `Specify.defconfig/2` and `Specify.Options`.
  """
  def load(struct, module)
end

defimpl Specify.Provider, for: List do
  def load(list, _module) do
    {:ok, Enum.into(list, %{})}
  end
end
