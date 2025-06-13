defmodule Anthropix.Messages.StreamingResponse do
  @moduledoc """
  Handles streaming responses from the Anthropic Messages API.

  A `StreamingResponse` represents an active streaming HTTP request that sends
  Server-Sent Events (SSE) containing message chunks. It provides multiple ways
  to consume the stream: callback-based event handling, native Elixir streams,
  or blocking until completion.

  ## Examples

  Register event handlers and await the final response:

  ```ex
  {:ok, response} =
    Messages.Request.stream(request)
    |> StreamingResponse.on(:event, &IO.inspect/1)
    |> StreamingResponse.on(:text, &IO.write/1)
    |> StreamingResponse.on(:complete, fn res -> IO.puts("Done!") end)
    |> StreamingResponse.run()
  ```

  Convert to a lazy stream for text chunks:

  ```ex
  Messages.Request.stream(request)
  |> StreamingResponse.text_stream()
  |> Stream.each(&IO.write/1)
  |> Stream.run()
  ```

  Mix callback handlers with streaming:

  ```ex
  Messages.Request.stream(request)
  |> StreamingResponse.on(:complete, &log_completion/1)
  |> StreamingResponse.stream()
  |> Stream.each(&process_event/1)
  |> Stream.run()
  ```

  ## Event Types

  - `:event` - Raw SSE event data (fired for every event)
  - `:text` - Text content from text delta events
  - `:complete` - Final assembled response when streaming completes
  - `:error` - Error information if the stream fails

  Note: A `StreamingResponse` can only be consumed once. Choose either `run/1`,
  `stream/1`, or `text_stream/1` - they cannot be used together.
  """
  alias Anthropix.{APIError, Messages}
  @enforce_keys [:pid, :ref]
  defstruct [:pid, :ref, handlers: []]

  @type t() :: %__MODULE__{
    pid: pid(),
    ref: reference(),
    handlers: list({event(), event_handler()})
  }

  @type event() :: :event | :text | :complete | :error
  @type event_handler() :: (event :: any() -> any())

  @events [:event, :text, :complete, :error]

  @sse_regex ~r/event:\s*(\w+)\ndata:\s*({.+})\n/

  @sse_events [
    "message_start",
    "content_block_start",
    "content_block_delta",
    "content_block_stop",
    "message_delta",
    "message_stop",
  ]

  @doc false
  @spec init(Req.Request.t()) :: t()
  def init(req) do
    # Spawn buffer process
    pid = spawn fn ->
      receive do
        {:start, from, ref} ->
          buffer_loop(from, ref)
      after
        # start timeout
        30_000 -> :timeout
      end
    end

    ref = Process.monitor(pid)

    # Spawn async request
    spawn fn ->
      result = Req.post(req, into: fn {:data, data}, {req, res} ->
        # Get buffer from response private data, or start with empty binary
        buffer = Req.Response.get_private(res, :sse_buffer, "")

        # Process complete events and get any remaining partial data
        {events, buffer} = decode_sse_events(buffer <> data)

        # Update response with new buffer
        res = Req.Response.put_private(res, :sse_buffer, buffer)

        for event <- events do
          case event.type do
            type when type in @sse_events ->
              send(pid, {ref, {:data, event}})

            "error" ->
              send(pid, {ref, {:error, APIError.exception(event)}})

            _ ->
              nil # ignore unknown events
          end
        end

        {:cont, {req, res}}
      end)

      send(pid, {ref, result})
    end

    struct(__MODULE__, pid: pid, ref: ref)
  end

  @doc """
  Registers an event handler for the specified event type.

  Handlers are called synchronously in the order they were registered.
  Returns an updated `StreamingResponse` with the handler attached.
  """
  @spec on(streaming :: t(), event(), event_handler()) :: t()
  def on(%__MODULE__{} = streaming, event, handler)
    when event in @events
    and is_function(handler, 1),
    do: update_in(streaming.handlers, & &1 ++ [{event, handler}])

  @doc """
  Consumes the streaming response and returns the final assembled result.

  Blocks until the stream completes, calling any registered event handlers as
  events arrive. Returns the same response structure as the synchronous Messages
  API.
  """
  @spec run(streaming :: t()) :: {:ok, Messages.Response.t()} | {:error, term()}
  def run(%__MODULE__{} = streaming) do
    streaming
    |> run_start()
    |> run_loop()
  end

  @doc """
  Converts the streaming response into a lazy enumerable of all events.

  Each item in the stream is a raw SSE event map. The stream will emit events as
  they arrive from the server.
  """
  @spec stream(streaming :: t()) :: Enumerable.t(map())
  def stream(%__MODULE__{} = streaming) do
    Stream.resource(
      fn ->
        {run_start(streaming), %{}}
      end,
      fn {streaming, acc} ->
        case receive_next(streaming, acc) do
          {:data, data, acc} ->
            {[data], {streaming, acc}}

          _message ->
            {:halt, {streaming, acc}}
        end
      end,
      fn _ -> :ok end
    )
  end

  @doc """
  Converts the streaming response into a lazy enumerable of text chunks.

  Filters for text delta events and extracts only the text content.
  Useful for processing streaming text output without handling other event types.
  """
  @spec text_stream(streaming :: t()) :: Enumerable.t(String.t())
  def text_stream(%__MODULE__{} = streaming) do
    stream(streaming)
    |> Stream.filter(& &1.type == "content_block_delta" and &1.delta.type == "text_delta")
    |> Stream.map(& &1.delta.text)
  end

  # Buffer loop

  defp buffer_loop(from, ref) do
    receive do
      {^ref, _} = message ->
        send(from, message)
        buffer_loop(from, ref)

    after
      # receive timeout
      15_000 -> :timeout
    end
  end

  # Run loop

  @spec run_start(streaming :: t()) :: t()
  defp run_start(%__MODULE__{pid: pid, ref: ref} = streaming) do
    send(pid, {:start, self(), ref})
    streaming
  end

  @spec run_loop(streaming :: t(), acc :: map()) :: {:ok, Messages.Response.t()} | {:error, term()}
  defp run_loop(%__MODULE__{} = streaming, acc \\ %{}) do
    case receive_next(streaming, acc) do
      {:data, _data, acc} -> run_loop(streaming, acc)
      result -> result
    end
  end

  @spec receive_next(streaming :: t(), acc :: map()) :: {:data, map(), map()} | {:ok, Messages.Response.t()} | {:error, term()}
  defp receive_next(%__MODULE__{ref: ref} = streaming, acc) do
    receive do
      {^ref, {:data, data}} ->
        call_data_handlers(streaming, data)
        {:data, data, merge_event(acc, data)}

      {^ref, {:ok, %{status: status} = res}} when status in 200..299 ->
        with {:ok, res} <- Messages.Response.new(%{res | body: acc}) do
          call_handlers(streaming, :complete, res)
          {:ok, res}
        end

      {^ref, {:ok, res}} ->
        error = APIError.exception(res)
        call_handlers(streaming, :error, error)
        {:error, error}

      {^ref, {:error, error}} ->
        call_handlers(streaming, :error, error)
        {:error, error}

    after
      # receive timeout
      15_000 -> {:error, :timeout}
    end
  end

  # Helpers

  @spec call_handlers(streaming :: t(), event(), data :: any()) :: :ok
  defp call_handlers(%__MODULE__{handlers: handlers}, event, data) when event in @events do
    handlers
    |> Enum.filter(& elem(&1, 0) == event)
    |> Enum.each(& elem(&1, 1).(data))
  end

  defp call_data_handlers(%__MODULE__{} = streaming, data) do
    # Alyways call "event" handlers
    call_handlers(streaming, :event, data)

    with %{type: "content_block_delta", delta: delta} <- data do
      case delta.type do
        "text_delta" -> call_handlers(streaming, :text, delta.text)
        _ -> :ok
      end
    else
      _ -> :ok
    end
  end

  @spec decode_sse_events(data :: binary()) :: {list(map()), binary()}
  defp decode_sse_events(data) do
    case Regex.scan(@sse_regex, data) do
      [] ->
        {[], data}

      matches ->
        events = for [_, _event, data] <- matches do
          # Trusting Anthropic won't suddenly spam a gazillion unknown keys.
          Jason.decode!(data, keys: :atoms)
        end
        {events, ""}
    end
  end

  @spec merge_event(acc :: map(), sse_event :: map()) :: map()
  defp merge_event(acc, %{type: "message_start", message: message}),
    do: Map.merge(acc, message)

  defp merge_event(acc, %{type: "content_block_start", index: i, content_block: block}),
    do: update_in(acc.content, & List.insert_at(&1, i, block))

  defp merge_event(acc, %{type: "content_block_delta", index: i, delta: delta}) do
    update_in(acc.content, fn content ->
      List.update_at(content, i, fn block ->
        case delta.type do
          "text_delta" -> update_in(block.text, & &1 <> delta.text)
          "thinking_delta" -> update_in(block.thinking, & &1 <> delta.thinking)
          "signature_delta" -> put_in(block.signature, delta.signature)
          "input_json_delta" ->
            update_in(block.input, fn input ->
              Map.update(input, :_json, delta.partial_json, & &1 <> delta.partial_json)
            end)
          _unknown -> block
        end
      end)
    end)
  end

  defp merge_event(acc, %{type: "content_block_stop", index: i}) do
    update_in(acc.content, fn content ->
      List.update_at(content, i, fn block ->
        case get_in(block, [:input, :_json]) do
          json when is_binary(json) and byte_size(json) > 0 ->
            put_in(block.input, Jason.decode!(json))

          _ -> block
        end
      end)
    end)
  end

  defp merge_event(acc, %{type: "message_delta", delta: delta}),
    do: Map.merge(acc, delta)

  # Handles message_stop and any unknown events
  defp merge_event(acc, _data), do: acc

end
