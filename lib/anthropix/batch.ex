defmodule Anthropix.Batch do
  @moduledoc """
  The [message batches API](https://docs.anthropic.com/en/docs/build-with-claude/message-batches)
  is a powerful, cost-effective way to asynchronously process large volumes of
  messages requests. This approach is well-suited to tasks that do not require
  immediate responses, reducing costs by 50% while increasing throughput.
  """
  use Anthropix.Schemas
  alias Anthropix.APIError

  schema :list_params, [
    before_id: [
      type: :string,
      doc: "Returns the page of results immediately before this object.",
    ],
    after_id: [
      type: :string,
      doc: "Returns the page of results immediately after this object.",
    ],
    limit: [
      type: :integer,
      doc: "Number of items to return per page. Between 1-100 (default 20)."
    ],
  ]

  @doc """
  List all message batches. Most recently created batches are returned first.

  ## Options

  #{doc(:list_params)}

  ## Examples

  ```elixir
  iex> Anthropix.Batch.list(client)
  {:ok, %{"data" => [...]}}

  # With pagination options
  iex> Anthropix.Batch.list(client, after_id: "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R", limit: 50)
  {:ok, %{"data" => [...]}}
  ```
  """
  @spec list(Anthropix.client(), keyword()) :: any
  def list(%Anthropix{} = client, params \\ []) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:list_params)) do
      client
      |> req(:get, "/messages/batches", params: params)
      |> res()
    end
  end

  schema :batch_params, [
    custom_id: [
      type: :string,
      required: true,
      doc: "Developer-provided ID created for each request in a Message Batch."
    ],
    params: [
      type: :map,
      keys: Anthropix.chat_schema(),
      required: true,
      doc: "Messages API creation parameters for the individual request."
    ]
  ]

  schema :create_params, [
    requests: [
      type: {:list, {:map, schema(:batch_params).schema}},
      required: true,
      doc: "List of requests for prompt completion."
    ]
  ]

  @doc """
  Send a batch of message creation requests. Used to process multiple message
  requests in a single batch. Processing begins immediately.

  ## Options

  #{doc(:create_params)}

  ## Examples

  ```elixir
  iex> Anthropix.Batch.create(client, [
  ...>   %{custom_id: "foo", params: %{model: "claude-3-haiku-20240307", messages: [%{role: "user", content: "Why is the sky blue?"}]}},
  ...>   %{custom_id: "bar", params: %{model: "claude-3-haiku-20240307", messages: [%{role: "user", content: "Why is the sea blue?"}]}},
  ...> ])
  {:ok, %{
    "type" => "message_batch",
    "id" => "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R"
    "processing_status" => "in_progress",
    ...
  }}
  ```
  """
  @spec create(Anthropix.client(), list(keyword())) :: any
  def create(%Anthropix{} = client, params \\ []) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:create_params)) do
      client
      |> req(:post, "/messages/batches", json: Enum.into(params, %{}))
      |> res()
    end
  end

  @doc """
  Cancels a message batch before processing ends. Depending on when cancellation
  is initiated, the number of cancelled messages requests will vary.

  ## Examples

  ```elixir
  iex> Anthropix.Batch.cancel(client, "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R")
  {:ok, %{
    "type" => "message_batch",
    "id" => "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R"
    "processing_status" => "canceling",
    ...
  }}
  ```
  """
  @spec cancel(Anthropix.client(), String.t()) :: any
  def cancel(%Anthropix{} = client, batch_id) when is_binary(batch_id) do
    client
    |> req(:post, "/messages/batches/#{batch_id}/cancel", [])
    |> res()
  end

  @doc """
  Retrieve the status of the batch. Can be used to poll for message batch
  completion.

  When the batch is ready, the `"processing_status"` will be `"ended"` and the
  response will include a `"results_url"` value.

  ## Examples

  ```elixir
  iex> Anthropix.Batch.show(client, "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R")
  {:ok, %{
    "type" => "message_batch",
    "id" => "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R"
    "processing_status" => "ended",
    "results_url" => "https://api.anthropic.com/v1/messages/batches/msgbatch_01DJuZbTFXpGRhqTdqFH1P2R/results",
    ...
  }}
  ```
  """
  @spec show(Anthropix.client(), String.t()) :: any
  def show(%Anthropix{} = client, batch_id) when is_binary(batch_id) do
    client
    |> req(:get, "/messages/batches/#{batch_id}", [])
    |> res()
  end

  schema :results_params, [
    stream: [
      type: {:or, [:boolean, :pid]},
      default: false,
      doc: "Whether to stream the batch results.",
    ],
  ]

  @doc """
  Retrieve the status of the batch. Will respond with or stream a list of chat
  message completions.

  It is preferred to pass the result of `show/2` directly, but also accepts a
  `results_url` or `batch_id` string.

  Results are not guaranteed to be in the same order as requests. Use the
  `custom_id` field to match results to requests.

  ## Options

  #{doc(:create_params)}

  ## Examples

  ```elixir
  iex> Anthropix.Batch.results(client, "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R")
  {:ok, [
    %{"custom_id" => "foo", "result" => %{...}},
    %{"custom_id" => "bar", "result" => %{...}},
  ]}

  # Passing true to the :stream option initiates an async streaming request.
  iex> Anthropix.Batch.results(client, "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R", stream: true)
  {:ok, #Function<52.53678557/2 in Stream.resource/3>}
  ```
  """
  @spec results(Anthropix.client(), String.t() | map(), keyword()) :: any
  def results(client, map_or_batch_id, params \\ [])

  def results(%Anthropix{} = client, %{"results_url" => url}, params)
    when is_binary(url),
    do: results(client, url, params)

  def results(%Anthropix{} = client, batch_id, params) when is_binary(batch_id) do
    url = case String.match?(batch_id, ~r/^https?:\/\//) do
      true -> batch_id
      false -> "/messages/batches/#{batch_id}/results"
    end

    with {:ok, params} <- NimbleOptions.validate(params, schema(:results_params)) do
      client
      |> req(:get, url, params)
      |> res()
    end
  end

  # Builds the request from the given params
  @spec req(Anthropix.client(), atom(), Req.url(), keyword()) :: Anthropix.req_response()
  defp req(%Anthropix{req: req}, method, url, opts) do
    opts = Keyword.merge(opts, method: method, url: url)
    {stream_opt, opts} = Keyword.pop(opts, :stream, false)
    dest = if is_pid(stream_opt), do: stream_opt, else: self()

    if stream_opt do
      opts = Keyword.put(opts, :into, stream_handler(dest))
      task = Task.async(fn -> Req.request(req, opts) |> res() end)

      case stream_opt do
        true -> {:ok, Stream.resource(fn -> task end, &stream_next/1, &stream_end/1)}
        _ -> {:ok, task}
      end
    else
      Req.request(req, opts)
    end
  end

  # Normalizes the response returned from the request
  @spec res(Anthropix.req_response()) :: Anthropix.response()
  defp res({:ok, %Task{} = task}), do: {:ok, task}
  defp res({:ok, enum}) when is_function(enum), do: {:ok, enum}

  defp res({:ok, %{status: status, body: body} = res}) when status in 200..299 do
    with [header] <- Req.Response.get_header(res, "content-disposition"),
         true <- String.match?(header, ~r/\.jsonl/)
    do
      results = body
      |> String.split("\n")
      |> Enum.map(&Jason.decode!/1)
      {:ok, results}
    else
      _ -> {:ok, body}
    end
  end

  defp res({:ok, resp}) do
    {:error, APIError.exception(resp)}
  end

  defp res({:error, error}), do: {:error, error}

  # Returns a callback to handle streaming responses
  @spec stream_handler(pid()) :: fun()
  defp stream_handler(pid) do
    fn {:data, data}, {req, res} ->
      data
      |> String.split("\n")
      |> Enum.map(&Jason.decode!/1)
      |> Enum.each(& Process.send(pid, {self(), {:data, &1}}, []))

      {:cont, {req, update_in(res.body, & &1 <> data)}}
    end
  end

  # Recieve messages into a stream
  defp stream_next(%Task{pid: pid, ref: ref} = task) do
    receive do
      {^pid, {:data, data}} ->
        {[data], task}

      {^ref, {:ok, %Req.Response{status: status}}} when status in 200..299 ->
        {:halt, task}

      {^ref, {:ok, %Req.Response{}=resp}} ->
        raise APIError.exception(resp)

      {^ref, {:error, error}} ->
        raise error

      {:DOWN, _ref, _, _pid, _reason} ->
        {:halt, task}
    after
      30_000 -> {:halt, task}
    end
  end

  # Tidy up when the streaming request is finished
  defp stream_end(%Task{ref: ref}), do: Process.demonitor(ref, [:flush])

end
