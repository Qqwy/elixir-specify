defmodule Confy do
  @moduledoc """
  Confy allows you to make your configuration explicit:

  - Specify exactly what fields are expected.
  - Specify exactly what values these fields might take, by giving them parser-functions.
  - Load their values from a slew of different locations, with 'explicitly passed in to the function' as final option.
  """

  defmacro defconfig(do: block) do
    quote do
      import Confy
      Module.register_attribute(__MODULE__, :config_fields, accumulate: true)
      try do
        unquote(block)
      after
        config_fields = Module.get_attribute(__MODULE__, :config_fields) |> Enum.reverse
        existing_moduledoc = Module.delete_attribute(__MODULE__, :moduledoc) || ""
        line_number = 0
        Module.put_attribute(__MODULE__, :moduledoc, {line_number, existing_moduledoc <> Confy.__config_doc__(config_fields)})

        defstruct(Confy.__struct_fields__(config_fields))
        @defaults Confy.__defaults__(config_fields)
        def __defaults__(), do: @defaults
        :ok
      end
    end
  end

  def fetch(config_module, explicit_config, options) do
    # TODO fetch from other source
    # TODO parse `options`.
    defaults = config_module.__defaults__
    struct(config_module, explicit_config)
  end

  @doc """
  Specifies a field that is part of the configuration struct.
  Supported options are:

  - `default:`, supplies a default value to this field. If not set, the configuration field is set to be _required_.

  You are highly encouraged to add a `@doc`umentation text above each and every field;
  these will be added to the configuration's module documentation.
  """
  defmacro field(name, parser, opts \\ []) do
    quote do
      field_documentation = Module.delete_attribute(__MODULE__, :doc)
      field_documentation =
        case field_documentation do
          {_line, val} -> val
          nil ->
            IO.warn("Missing documentation for configuration field `#{unquote(name)}`. Please add it by adding `@doc \"field documentation here\"` above the line where you define it.")
            ""
        end
      Confy.__field__(__MODULE__, unquote(name), unquote(parser), field_documentation, unquote(opts))
    end
  end

  @doc false
  def __field__(module, name, parser, field_documentation, options) do
    parser = handle_parser(parser)
    Module.put_attribute(module, :config_fields, {name, parser, field_documentation, options})
  end

  # Extracts the struct definition keyword list
  # from the outputs of the list of `field` calls.
  @doc false
  def __struct_fields__(config_fields) do
    config_fields
    |> Enum.map(fn {name, parser, documentation, options} ->
      {name, options[:default]}
    end)
  end

  def __config_doc__(config_fields) do
    acc =
      config_fields
      |> Enum.reduce("", fn {name, parser, documentation, options}, acc ->
          doc = """

          #### #{name}

          #{documentation || "ASDF"}

          Validated/parsed by calling `#{Macro.to_string(parser)}`.
          """

          doc =
            case Access.fetch(options, :default) do
              {:ok, val} -> """
                #{doc}
                Defaults to `#{inspect(val)}`.
                """
              :error -> """
                #{doc}
                Required.
                """
          end

          acc <> doc
        end)

    """
    ### Configuration structure documentation:

    #{acc}
    """
  end

  @doc false
  def __defaults__(config_fields) do
    config_fields
    |> Enum.filter(fn {name, _parser, _documentation, options} ->
      case Access.fetch(options, :default) do
        {:ok, _} -> true
        :error -> false
      end
    end)
    |> Enum.map(fn {name, parser, _documentation, options} ->
      {name, options[:default]}
    end)
    |> Enum.into(%{})
  end

  defp handle_parser(parser) when is_atom(parser) do
    case Confy.Parsers.__info__(:functions)[parser] do
      nil -> raise ArgumentError, "Parser shorthand `#{inspect(parser)}` was not recognized. Only atoms representing names of functions that live in `Confy.Parsers` are."
      1 -> quote do &Confy.Parsers.unquote(parser)/1 end
    end
  end
  defp handle_parser(other), do: other
end
