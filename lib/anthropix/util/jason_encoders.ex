defimpl Jason.Encoder, for: Anthropix.Message do
  def encode(%Anthropix.Message{} = message, opts) do
    message
    |> Map.from_struct()
    |> Jason.Encode.map(opts)
  end
end

defimpl Jason.Encoder, for: Anthropix.Tool do
  def encode(%Anthropix.Tool{} = tool, opts) do
    tool
    |> Anthropix.Tool.to_map()
    |> Jason.Encode.map(opts)
  end
end

defimpl Jason.Encoder, for: [Xema, Xema.Schema] do
  def encode(schema, opts) do
    schema
    |> Anthropix.Util.XemaHelpers.xema_to_map()
    |> Jason.Encode.map(opts)
  end
end
