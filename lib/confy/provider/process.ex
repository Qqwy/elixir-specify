defmodule Confy.Provider.Process do
  defstruct [:key]
  def new(key \\ nil) do
    %__MODULE__{key: key}
  end

  defimpl Confy.Provider do
    def load(%Confy.Provider.Process{key: nil}, module) do
      load(%Confy.Provider.Process{key: module}, module)
    end
    def load(%Confy.Provider.Process{key: key}, _module) do
      case Process.get(key, :there_is_no_confy_configuration_in_this_process_dictionary!) do
        map when is_map(map) ->
          {:ok, map}
        list when is_list(list) ->
          {:ok, Enum.into(list, %{})}
        :there_is_no_confy_configuration_in_this_process_dictionary! ->
          {:error, :not_found}
        other ->
          {:error, :malformed}
      end
    end
  end
end

defimpl Confy.Provider, for: PID do
  def load(process, module) do
    {:dictionary, res}= Process.info(process, :dictionary)
    case Access.fetch(res, module) do
      {:ok, map} when is_map(map) ->
        {:ok, map}
      {:ok, list} when is_list(list) ->
        {:ok, Enum.into(list, %{})}
      :error ->
        {:error, :not_found}
      other ->
        {:error, :malformed}
    end
  end
end
