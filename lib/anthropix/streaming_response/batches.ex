defmodule Anthropix.StreamingResponse.Batches do
  use Anthropix.StreamingResponse, merge_into: []
  import Anthropix.Util.MapUtils, only: [safe_atomize_keys: 1]
  alias Anthropix.Batches

  @impl true
  def handle_buffer(buffer) do
    {lines, [remaining]} =
      buffer
      |> String.split("\n")
      |> Enum.split(-1)

    events =
      lines
      |> Enum.reject(& &1 == "")
      |> Enum.map(& {:data, Jason.decode!(&1)})

    {events, remaining}
  end

  @impl true
  def handle_merge(data, acc), do: [data | acc]

  @impl true
  def handle_complete(res) do
    result =
      res.body
      |> Enum.reverse()
      |> Enum.map(&safe_atomize_keys/1)
      |> Enum.map(&Batches.result!/1)

    {:ok, result}
  end

end
