defprotocol Confy.Provider do
  def load(struct, _module)
end

defimpl Confy.Provider, for: List do
  def load(list, _module) do
    {:ok, Enum.into(list, %{})}
  end
end
