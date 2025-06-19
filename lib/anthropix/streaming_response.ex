defmodule Anthropix.StreamingResponse do
  @moduledoc """
  Handles streaming responses with pluggable adapters for different data formats.

  A `StreamingResponse` represents an active streaming HTTP request that
  processes incoming data through an adapter module. Adapters handle
  format-specific parsing (such as Server-Sent Events or JSONL), emit custom
  events, and merge data into an accumulated response. `StreamingResponse`
  provides multiple ways to consume the stream: callback-based event handling,
  native Elixir streams, or blocking until completion.

  ## Usage

  Register event handlers and await the final response:

  ```ex
  {:ok, response} =
    Messages.Request.stream(request)
    |> StreamingResponse.on(:data, &IO.inspect/1)
    |> StreamingResponse.on(:text, &IO.write/1)
    |> StreamingResponse.on(:complete, fn res -> IO.puts("Done!") end)
    |> StreamingResponse.run()
  ```

  Convert to a lazy stream for text chunks:

  ```ex
  Messages.Request.stream(request)
  |> StreamingResponse.stream(:text)
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

  Note: A `StreamingResponse` can only be consumed once. Choose either `run/1`,
  `stream/1` or `stream/2` - they cannot be used together.

  ## Event types

  Built-in events emitted by all adapters:

  - `:data` - Raw data event (fired for every event)
  - `:complete` - Final assembled response when streaming completes
  - `:error` - Error information if the stream fails

  Custom events are adapter-specific. For example, the Messages adapter provides:

  - `:text` - Text content from text delta events

  See your adapter's documentation for available custom events.

  ## Implementing custom adapters

  Adapters implement the `StreamingResponse` behaviour to handle different
  streaming formats. The adapter is responsible for parsing the binary buffer,
  emitting events, and merging data events into the final response structure.

  To create a custom adapter, use this module and implement the required callbacks:

  ```ex
  defmodule MyAdapter do
    use Anthropix.StreamingResponse, merge_into: %{}

    @impl true
    def handle_buffer(buffer) do
      # Parse binary buffer, return {events, remaining_buffer}
    end

    @impl true
    def handle_merge(data, acc) do
      # Merge data event into accumulator
    end
  end
  ```

  ### Options

  - `:merge_into` - Initial accumulator value (default: `""`)

  ### Callbacks

  Required callbacks:

  - `c:handle_buffer/1` - Parses binary chunks into data events
  - `c:handle_merge/2` - Merges data events into the response accumulator

  Optional callbacks:

  - `c:handle_emit/1` - Emits custom events from parsed data
  - `c:handle_stream/2` - Provides filtered streams for specific data types
  """
  alias Anthropix.APIError

  @enforce_keys [:pid, :ref, :adapter]
  defstruct [:pid, :ref, :adapter, handlers: %{}]

  @type t() :: %__MODULE__{
    pid: pid(),
    ref: reference(),
    adapter: module(),
    handlers: %{event() => list(event_handler())}
  }

  @type event() :: :data | :complete | :error | atom()
  @type event_handler() :: (event :: any() -> any())

  # Callbacks

  @doc """
  Handles extracting data events from the binary buffer.

  Returns a tuple with a list of events and the remaining buffer.
  """
  @callback handle_buffer(buffer :: binary()) :: {
    list({:data | :error, any()}),
    binary()
  }

  @doc """
  Handles emitting custom events from parsed data.

  Takes a data event and returns a list of custom event tuples that will be
  emitted to event handlers.

  Returns a list of `{event_name, event_data}` tuples.
  """
  @callback handle_emit(data :: any()) :: list({event(), data :: any()})

  @doc """
  Handles merging data events into a response body.

  Returns the updated accumulator.
  """
  @callback handle_merge(data :: any(), acc :: any()) :: acc :: any()

  @doc """
  Handles filtering streams by data type.

  Takes a base stream of data events and a filter atom, returning a filtered
  stream with adapter-specific transformations applied. For example, a Messages
  adapter might filter for `:text` events and extract just the text content.

  Returns a filtered and transformed enumerable.
  """
  @callback handle_stream(stream :: Enumerable.t(), filter :: atom()) :: Enumerable.t()

  @doc """
  Handles transforming the final response when streaming completes.

  Takes the complete `Req.Response` struct with the accumulated data as the body
  and transforms it into the final response structure. This is called once when
  the stream successfully completes, before emitting the `:complete` event.

  Returns `{:ok, response}` on success or `{:error, reason}` if the final
  response cannot be constructed.
  """
  @callback handle_complete(res :: Req.Response.t()) :: {:ok, any()} | {:error, term()}

  @optional_callbacks handle_emit: 1, handle_stream: 2

  # Functions

  @doc false
  @spec init(Req.Request.t(), module()) :: t()
  def init(%Req.Request{} = req, adapter) when is_atom(adapter) do
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
      result = Req.request(req, into: fn {:data, data}, {req, res} ->
        # Get or create streaming buffer binary
        buffer = Req.Response.get_private(res, :streaming_buffer, "")

        # Handle chunk data
        {events, buffer} = apply(adapter, :handle_buffer, [buffer <> data])

        # Send messages and update buffer
        for {key, event} <- events, do: send(pid, {ref, {key, event}})
        res = Req.Response.put_private(res, :streaming_buffer, buffer)

        {:cont, {req, res}}
      end)

      send(pid, {ref, result})
    end

    struct(__MODULE__, pid: pid, ref: ref, adapter: adapter)
  end

  @doc """
  Registers an event handler for the specified event type.

  Handlers are called synchronously in the order they were registered.
  Returns an updated `StreamingResponse` with the handler attached.
  """
  @spec on(streaming :: t(), event(), event_handler()) :: t()
  def on(%__MODULE__{} = streaming, event, handler) when is_function(handler, 1) do
    update_in(streaming.handlers, fn map ->
      Map.update(map, event, [handler], & &1 ++ [handler])
    end)
  end

  @doc """
  Consumes the streaming response and returns the final assembled result.

  Blocks until the stream completes, calling any registered event handlers as
  events arrive. Returns the same response structure as a synchronous request.
  """
  @spec run(streaming :: t()) :: {:ok, any()} | {:error, term()}
  def run(%__MODULE__{adapter: adapter} = streaming) do
    acc = apply(adapter, :merge_into, [])
    streaming
    |> run_start()
    |> run_loop(acc)
  end

  @doc """
  Consumes the streaming response asynchronously.

  Returns a `Task` that will complete with the final assembled result.
  Equivalent to calling `run/1` in a separate process.
  """
  @spec run_async(streaming :: t()) :: Task.t()
  def run_async(%__MODULE__{} = streaming) do
    Task.async(fn -> run(streaming) end)
  end

  @doc """
  Converts the streaming response into a lazy enumerable of data events.

  The stream emits data events as they arrive from the server. Each item
  is a parsed data event returned from the adapter's `c:handle_buffer/1`
  implementation.
  """
  @spec stream(streaming :: t()) :: Enumerable.t()
  def stream(%__MODULE__{adapter: adapter} = streaming) do
    Stream.resource(
      fn ->
        acc = apply(adapter, :merge_into, [])
        {run_start(streaming), acc}
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
  Converts the streaming response into a lazy enumerable with optional filtering.

  When called with a filter, delegates to the adapter's `c:handle_stream/2`
  callback to provide filtered and transformed data. For example, using `:text`
  with a Messages adapter returns a stream of text content only.

  The base stream emits data events as they arrive from the server. Each item
  is a parsed data event returned from the adapter's `c:handle_buffer/1`
  implementation.

  ## Examples

  Stream all data events:

  ```ex
  stream
  |> StreamingResponse.stream()
  |> Stream.each(&process_data/1)
  |> Stream.run()
  ```

  Stream filtered text content:

  ```ex
  stream
  |> StreamingResponse.stream(:text)
  |> Stream.each(&IO.write/1)
  |> Stream.run()
  ```
  """
  @spec stream(streaming :: t(), filter :: atom()) :: Enumerable.t(map())
  def stream(%__MODULE__{adapter: adapter} = streaming, filter) do
    base_stream = stream(streaming)

    if function_exported?(adapter, :handle_stream, 2) do
      apply(adapter, :handle_stream, [base_stream, filter])
    else
      raise ArgumentError, "Adapter #{adapter} does not support stream filtering"
    end
  end

  # Macros

  defmacro __using__(opts \\ []) do
    res = Keyword.get(opts, :merge_into, "")

    quote do
      @behaviour Anthropix.StreamingResponse

      @impl Anthropix.StreamingResponse
      def handle_complete(res), do: {:ok, res}

      @doc false
      def merge_into(), do: unquote(res)

      defoverridable handle_complete: 1
    end
  end

  # Buffer loop

  @spec buffer_loop(from :: pid(), ref :: reference()) :: :ok | :timeout
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

  @spec run_loop(streaming :: t(), acc :: any()) :: {:ok, any()} | {:error, term()}
  defp run_loop(%__MODULE__{} = streaming, acc) do
    case receive_next(streaming, acc) do
      {:data, _data, acc} -> run_loop(streaming, acc)
      result -> result
    end
  end

  @spec receive_next(streaming :: t(), acc :: any()) :: {:data, any(), any()} | {:ok, any()} | {:error, term()}
  defp receive_next(%__MODULE__{ref: ref, adapter: adapter} = streaming, acc) do
    receive do
      {^ref, {:data, data}} ->
        apply_handlers(streaming, :data, data)
        if function_exported?(adapter, :handle_emit, 1) do
          for {event, data} <- apply(adapter, :handle_emit, [data]) do
            apply_handlers(streaming, event, data)
          end
        end
        acc = apply(adapter, :handle_merge, [data, acc])
        {:data, data, acc}

      {^ref, {:ok, %{status: status} = res}} when status in 200..299 ->
        case apply(adapter, :handle_complete, [%{res | body: acc}]) do
          {:ok, result} ->
            apply_handlers(streaming, :complete, result)
            {:ok, result}
          {:error, error} ->
            apply_handlers(streaming, :error, error)
            {:error, error}
        end

      {^ref, {:ok, res}} ->
        error = APIError.exception(res)
        apply_handlers(streaming, :error, error)
        {:error, error}

      {^ref, {:error, error}} ->
        apply_handlers(streaming, :error, error)
        {:error, error}

    after
      # receive timeout
      15_000 -> {:error, :timeout}
    end
  end

  # Helpers

  @spec apply_handlers(streaming :: t(), event(), data :: any()) :: :ok
  defp apply_handlers(%__MODULE__{handlers: handlers}, event, data) do
    for handler <- Map.get(handlers, event, []) do
      apply(handler, [data])
    end
    :ok
  end

end
