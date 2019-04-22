defmodule Confy.Provider.SystemEnv do
  @moduledoc """
  A Configuration Provider source based on `System.get_env/2`

  Values will be loaded based on `\#{prefix}_\#{capitalized_field_name}`.
  `prefix` defaults to the capitalized name of the configuration specification module.
  `capitalized_field_name` is in `CONSTANT_CASE` (all-caps, with underscores as word separators).

  iex> defmodule Elixir.Pet do
  iex>   require Confy
  iex>   Confy.defconfig do
  iex>     @doc "The name of the pet"
  iex>     field :name, :string
  iex>     @doc "is it a dog or a cat?"
  iex>     field :kind, :atom
  iex>   end
  iex> end
  iex> System.put_env("PET_NAME", "Timmy")
  iex> System.put_env("PET_KIND", "cat")
  iex> Pet.load(sources: [Confy.Provider.SystemEnv.new("PET")])
  %Pet{name: "Timmy", kind: :cat}

  iex> System.put_env("SECOND_PET_NAME", "Bobby")
  iex> System.put_env("SECOND_PET_KIND", "cat")
  iex> Pet.load(sources: [Confy.Provider.SystemEnv.new("SECOND_PET")])
  %Pet{name: "Bobby", kind: :cat}

  """
  defstruct [:prefix]

  @doc """

  """
  def new(prefix \\ nil) do
    %__MODULE__{prefix: prefix}
  end

  defimpl Confy.Provider do
    def load(%Confy.Provider.SystemEnv{prefix: nil}, module) do
      capitalized_prefix =
        module
        |> Macro.to_string()
        |> String.upcase()

      load(%Confy.Provider.SystemEnv{prefix: capitalized_prefix}, module)
    end

    def load(%Confy.Provider.SystemEnv{prefix: prefix}, module) do
      full_env = System.get_env()

      res =
        Enum.reduce(module.__confy__(:field_options), %{}, fn {name, options}, acc ->
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
