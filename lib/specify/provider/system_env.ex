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
          field :kind, :atom
        end
      end

      iex> System.put_env("PET_NAME", "Timmy")
      iex> System.put_env("PET_KIND", "cat")
      iex> Pet.load(sources: [Specify.Provider.SystemEnv.new()])
      %Pet{name: "Timmy", kind: :cat}
      iex> Pet.load(sources: [Specify.Provider.SystemEnv.new("PET")])
      %Pet{name: "Timmy", kind: :cat}

      iex> System.put_env("SECOND_PET_NAME", "John")
      iex> System.put_env("SECOND_PET_KIND", "dog")
      iex> Pet.load(sources: [Specify.Provider.SystemEnv.new("SECOND_PET")])
      %Pet{name: "John", kind: :dog}

  """
  defstruct [:prefix]

  @doc """

  """
  def new(prefix \\ nil) do
    %__MODULE__{prefix: prefix}
  end

  defimpl Specify.Provider do
    def load(%Specify.Provider.SystemEnv{prefix: nil}, module) do
      capitalized_prefix =
        module
        |> Macro.to_string()
        |> String.upcase()

      load(%Specify.Provider.SystemEnv{prefix: capitalized_prefix}, module)
    end

    def load(%Specify.Provider.SystemEnv{prefix: prefix}, module) do
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
        {:error, :not_found}
      else
        {:ok, res}
      end
    end
  end
end
