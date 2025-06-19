defmodule Anthropix.StreamingResponse.Messages do
  use Anthropix.StreamingResponse, merge_into: %{}
  alias Anthropix.{APIError, Messages}

	@sse_regex ~r/event:[\s\w]+\ndata:\s*(\{[^\n]*\})\n/s

  @sse_events [
    "message_start",
    "content_block_start",
    "content_block_delta",
    "content_block_stop",
    "message_delta",
    "message_stop",
    "error"
  ]

  # Callbacks

	@impl true
	def handle_buffer(buffer) do
	  case Regex.scan(@sse_regex, buffer) do
      [] ->
        {[], buffer}

      matches ->
        events =
          matches
          |> Enum.map(fn [_full, match] -> Jason.decode!(match) end)
          |> Enum.filter(& &1["type"] in @sse_events)
          |> Enum.map(&label_event/1)

        remaining =
          matches
          |> List.last()
          |> slice_buffer(buffer)

        {events, remaining}
    end
	end

	@impl true
	def handle_emit(event) do
	  case event do
			%{"type" => "content_block_delta", "delta" => %{"type" => "text_delta"} = delta} ->
			  [{:text, delta["text"]}]
      _ ->
        []
		end
	end

	@impl true
	def handle_merge(event, acc) do
	  case event do
			%{"type" => "message_start", "message" => message} ->
			  Map.merge(acc, message)

			%{"type" => "content_block_start", "index" => i, "content_block" => block} ->
			  update_in(acc, ["content"], & List.insert_at(&1, i, block))

			%{"type" => "content_block_delta", "index" => i, "delta" => delta} ->
   	    update_in(acc, ["content"], fn content ->
          List.update_at(content, i, fn block ->
            case delta["type"] do
              "text_delta" -> update_in(block, ["text"], & &1 <> delta["text"])
              "thinking_delta" -> update_in(block, ["thinking"], & &1 <> delta["thinking"])
              "signature_delta" -> put_in(block, ["signature"], delta["signature"])
              "input_json_delta" ->
                update_in(block, ["input"], fn input ->
                  Map.update(input, :_json, delta["partial_json"], & &1 <> delta["partial_json"])
                end)
              _unknown -> block
            end
          end)
        end)

			%{"type" => "content_block_stop", "index" => i} ->
   	    update_in(acc, ["content"], fn content ->
          List.update_at(content, i, fn block ->
            case get_in(block, ["input", :_json]) do
              json when is_binary(json) and byte_size(json) > 0 ->
                put_in(block, ["input"], Jason.decode!(json))

              _ -> block
            end
          end)
        end)

      %{"type" => "message_delta", "delta" => delta} ->
        Map.merge(acc, delta)

      _event ->
        acc
		end
	end

	@impl true
  def handle_stream(stream, :text) do
    stream
    |> Stream.filter(& &1["type"] == "content_block_delta" and get_in(&1, ["delta", "type"]) == "text_delta")
    |> Stream.map(& get_in(&1, ["delta", "text"]))
  end

  @impl true
  def handle_complete(res), do: Messages.Response.new(res)

	# Helpers

	@spec label_event(any()) :: {:data, map()} | {:error, term()}
	defp label_event(event) do
    case event do
      %{"type" => "error"} = error -> {:error, APIError.exception(error)}
      event -> {:data, event}
    end
  end

	@spec slice_buffer(list(String.t()), binary()) :: binary()
	defp slice_buffer([_full_match, last_match], buffer) do
		buffer
		|> String.split(last_match)
    |> List.last()
    |> String.trim()
	end

end
