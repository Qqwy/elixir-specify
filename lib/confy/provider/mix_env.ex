defmodule Confy.Provider.MixEnv do
  defstruct [:application, :key]

  def new(application, key \\ nil) do
    %__MODULE__{application: application, key: key}
  end

  defimpl Confy.Provider do
    def load(%Confy.Provider.MixEnv{application: application, key: nil}, module) do
      load(%Confy.Provider.MixEnv{application: application, key: module}, module)
    end
    def load(%Confy.Provider.MixEnv{application: application, key: key}, _module) do
      case Application.get_env(application, key, :there_is_no_confy_configuration_in_this_application_environment!) do
        map when is_map(map) ->
          {:ok, map}
        list when is_list(list) ->
          {:ok, Enum.into(list, %{})}
        :there_is_no_confy_configuration_in_this_application_environment! ->
          {:error, :not_found}
        other ->
          {:error, :malformed}
      end
    end
  end
end