defmodule Confy.Options do
  require Confy
  Confy.defconfig do
    field :sources, :term, default: []
    field :missing_fields_error, :term, default: Confy.MissingRequiredFieldsError
    field :parsing_error, :term, default: Confy.ParsingError
    field :explain, :boolean, default: false
  end
end
