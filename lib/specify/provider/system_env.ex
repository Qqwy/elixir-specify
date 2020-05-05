defmodule Specify.Provider.SystemEnv do
  @moduledoc """
  A Configuration Provider source based on `System.get_env/2`

  Values will be loaded based on `\#{prefix}_\#{capitalized_field_name}`.
  `prefix` defaults to the capitalized name of the configuration specification module.
  `capitalized_field_name` is in `CONSTANT_CASE` (all-caps, with underscores as word separators).

  ### Examples

  The following examples use the following specification for reference:

      defmodule Elixir.Pet do
        require Specify
        Specify.defconfig do
          @doc "The name of the pet"
          field :name, :string
          @doc "is it a dog or a cat?"
          field :kind, :atom, system_env_name: "TYPE"
        end
      end

  Note that if a field has a different name than the environment variable you want to read from,
  you can add the `system_env_name:` option when specifying the field, as has been done for the `:kind` field
  in the example module above.

      iex> System.put_env("PET_NAME", "Timmy")
      iex> System.put_env("PET_TYPE", "cat")
      iex> Pet.load(sources: [Specify.Provider.SystemEnv.new()])
      %Pet{name: "Timmy", kind: :cat}
      iex> Pet.load(sources: [Specify.Provider.SystemEnv.new("PET")])
      %Pet{name: "Timmy", kind: :cat}

      iex> System.put_env("SECOND_PET_NAME", "John")
      iex> System.put_env("SECOND_PET_TYPE", "dog")
      iex> Pet.load(sources: [Specify.Provider.SystemEnv.new("SECOND_PET")])
      %Pet{name: "John", kind: :dog}

  """
  defstruct [:prefix, optional: false]

  @doc """

  """
  def new(prefix \\ nil, options \\ []) do
    optional = options[:optional] || false
    %__MODULE__{prefix: prefix, optional: optional}
  end

  defimpl Specify.Provider do
    def load(provider = %Specify.Provider.SystemEnv{prefix: nil}, module) do
      capitalized_prefix =
        module
        |> Macro.to_string()
        |> String.upcase()

      load(%Specify.Provider.SystemEnv{provider | prefix: capitalized_prefix}, module)
    end

    def load(%Specify.Provider.SystemEnv{prefix: prefix, optional: optional}, module) do
      full_env = System.get_env()

      res =
        Enum.reduce(module.__specify__(:field_options), %{}, fn {name, options}, acc ->
          capitalized_field_name = options[:system_env_name] || String.upcase(to_string(name))
          full_field_name = "#{prefix}_#{capitalized_field_name}"

          if Map.has_key?(full_env, full_field_name) do
            Map.put(acc, name, full_env[full_field_name])
          else
            acc
          end
        end)

      if res == %{} do
        if optional do
          {:ok, %{}}
        else
          {:error, :not_found}
        end
      else
        {:ok, res}
      end
    end
  end
end
