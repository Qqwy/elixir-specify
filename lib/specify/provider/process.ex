defmodule Specify.Provider.Process do
  defstruct [:key]

  @moduledoc """
  A Configuration Provider source based on the current process' Process Dictionary.

  ### Examples

  The following examples use the following specification for reference:

      defmodule Elixir.Pet do
        require Specify
        Specify.defconfig do
          @doc "The name of the pet"
          field :name, :string
          @doc "is it a dog or a cat?"
          field :kind, :atom
        end
      end
  """

  @doc """
  By default, will try to use `Process.get(YourModule)` to fetch the source's configuration.
  A different key can be used by supplying a different `key` argument.

      iex> Process.put(Pet, %{name: "Timmy", kind: :cat})
      iex> Pet.load(sources: [Specify.Provider.Process.new(Pet)])
      %Pet{name: "Timmy", kind: :cat}

      iex> Process.put(:another_pet, %{name: "John", kind: :dog})
      iex> Pet.load(sources: [Specify.Provider.Process.new(:another_pet)])
      %Pet{name: "John", kind: :dog}
  """

  def new(key \\ nil) do
    %__MODULE__{key: key}
  end

  defimpl Specify.Provider do
    def load(%Specify.Provider.Process{key: nil}, module) do
      load(%Specify.Provider.Process{key: module}, module)
    end

    def load(%Specify.Provider.Process{key: key}, _module) do
      case Process.get(key, :there_is_no_specify_configuration_in_this_process_dictionary!) do
        map when is_map(map) ->
          {:ok, map}

        list when is_list(list) ->
          {:ok, Enum.into(list, %{})}

        :there_is_no_specify_configuration_in_this_process_dictionary! ->
          {:error, :not_found}

        _other ->
          {:error, :malformed}
      end
    end
  end
end

# TODO: Should we even allow this?
# Looking into another process' dictionary is probably bad style, isn't it?
defimpl Specify.Provider, for: PID do
  def load(process, module) do
    {:dictionary, res} = Process.info(process, :dictionary)

    case Access.fetch(res, module) do
      {:ok, map} when is_map(map) ->
        {:ok, map}

      {:ok, list} when is_list(list) ->
        {:ok, Enum.into(list, %{})}

      :error ->
        {:error, :not_found}

      _other ->
        {:error, :malformed}
    end
  end
end
