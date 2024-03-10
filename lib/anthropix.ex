defmodule Anthropix do
  @version Keyword.fetch!(Mix.Project.config(), :version)
  @moduledoc """
  ![License](https://img.shields.io/github/license/lebrunel/anthropix?color=informational)

  An up-to-date and fully-featured Elixir client library for
  [Anthropic's REST API](https://docs.anthropic.com/claude/reference/getting-started-with-the-api).

  - ✅ API client fully implementing the Anthropic API
  - 🛜 Streaming API requests
    - Stream to an Enumerable
    - Or stream messages to any Elixir process
  - 🔜 Advanced and flexible function calling workflow

  This library is currently a WIP. Check back in a week or two, by which point
  it should be bangin!

  ## Installation

  The package can be installed by adding `anthropix` to your list of
  dependencies in `mix.exs`.

  ```elixir
  def deps do
    [
      {:anthropix, "#{@version}"}
    ]
  end
  ```

  ## Quickstart

  TODO...
  """
  use Anthropix.Schemas

  defstruct [:req]

  @typedoc "Client struct"
  @type client() :: %__MODULE__{
    req: Req.Request.t()
  }


  schema :content, [
    type: [type: :string, required: true],
    text: [type: :string],
    content: [type: :map, keys: [
      type: [type: :string, required: :true],
      media_type: [type: :string, required: :true],
      data: [type: :string, required: :true],
    ]]
  ]

  schema :message, [
    role: [
      type: :string,
      required: true,
      doc: "The role of the message, either `user` or `assistant`."
    ],
    content: [
      type: {:or, [:string, {:list, {:map, schema(:content).schema}}]},
      required: true,
      doc: "Message content, either a single string or an array of content blocks."
    ]
  ]

  @typedoc """
  Chat message

  A chat message is a `t:map/0` with the following fields:

  #{doc(:message)}
  """
  @type message() :: map()

  @typedoc "Client response"
  @type response() ::
    {:ok, map() | boolean() | Enumerable.t() | Task.t()} |
    {:error, term()}

  @typep req_response() ::
    {:ok, Req.Response.t() | Task.t() | Enum.t()} |
    {:error, term()}


  @default_req_opts [
    base_url: "https://api.anthropic.com/v1",
    headers: [
      {"anthropic-version", "2023-06-01"},
      {"user-agent", "anthropix/#{@version}"},
    ],
    receive_timeout: 60_000,
  ]

  @doc """
  Calling `init/1` without passing an API key, creates a new Anthropix API
  client using the API key set in your application's config.

  ```elixir
  config :anthropix, :api_key, "sk-ant-your-key"
  ```

  If given, a keyword list of options will be passed to `Req.new/1`.

  ## Examples

  ```elixir
  iex> client = Anthropix.init()
  %Anthropix{}
  ```
  """
  @spec init() :: client()
  def init(), do: init([])
  @spec init(keyword()) :: client()
  def init(opts) when is_list(opts) do
    Application.fetch_env!(:anthropix, :api_key) |> init(opts)
  end

  @doc """
  Calling `init/2` with an API key creates a new Anthropix API client, using the
  given API key. Optionally, a keyword list of options can be passed through to
  `Req.new/1`.

  ## Examples

  ```elixir
  iex> client = Anthropix.init("sk-ant-your-key", receive_timeout: :infinity)
  %Anthropix{}
  ```
  """
  @spec init(String.t(), keyword()) :: client()
  def init(api_key, opts \\ []) when is_binary(api_key) do
    {headers, opts} = Keyword.pop(opts, :headers, [])

    req = @default_req_opts
    |> Keyword.merge(opts)
    |> Req.new()
    |> Req.Request.put_header("x-api-key", api_key)
    |> Req.Request.put_headers(headers)

    struct(__MODULE__, req: req)
  end


  schema :messages, [
    model: [
      type: :string,
      required: true,
      doc: "The model that will complete your prompt.",
    ],
    messages: [
      type: {:list, {:map, schema(:message).schema}},
      required: true,
      doc: "Input messages.",
    ],
    system: [
      type: :string,
      doc: "System prompt.",
    ],
    max_tokens: [
      type: :integer,
      default: 4096,
      doc: "The maximum number of tokens to generate before stopping.",
    ],
    metadata: [
      type: :map,
      doc: "A map describing metadata about the request.",
    ],
    stop_sequences: [
      type: {:list, :string},
      doc: "Custom text sequences that will cause the model to stop generating.",
    ],
    stream: [
      type: {:or, [:boolean, :pid]},
      default: false,
      doc: "Whether to incrementally stream the response using server-sent events.",
    ],
    temperature: [
      type: :float,
      doc: "Amount of randomness injected into the response."
    ],
    top_k: [
      type: :integer,
      doc: "Only sample from the top K options for each subsequent token."
    ],
    top_p: [
      type: :float,
      doc: "Amount of randomness injected into the response."
    ],
  ]

  @doc """
  Send a structured list of input messages with text and/or image content, and
  the model will generate the next message in the conversation.

  ## Options

  #{doc(:messages)}

  ## Message structure

  Each message is a map with the following fields:

  #{doc(:message)}

  ## Examples

  ```elixir
  iex> messages = [
  ...>   %{role: "system", content: "You are a helpful assistant."},
  ...>   %{role: "user", content: "Why is the sky blue?"},
  ...>   %{role: "assistant", content: "Due to rayleigh scattering."},
  ...>   %{role: "user", content: "How is that different than mie scattering?"},
  ...> ]

  iex> Anthropix.messages(client, [
  ...>   model: "claude-3-opus-20240229",
  ...>   messages: messages,
  ...> ])
  {:ok, %{"content" => [%{
    "type" => "text",
    "text" => "Mie scattering affects all wavelengths similarly, while Rayleigh favors shorter ones."
  }], ...}}

  # Passing true to the :stream option initiates an async streaming request.
  iex> Anthropix.messages(client, [
  ...>   model: "claude-3-opus-20240229",
  ...>   messages: messages,
  ...>   stream: true,
  ...> ])
  {:ok, #Function<52.53678557/2 in Stream.resource/3>}
  ```
  """
  @spec messages(client(), keyword()) :: any()
  def messages(%__MODULE__{} = client, params \\ []) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:messages)) do
      client
      |> req(:post, "/messages", json: Enum.into(params, %{}))
      |> res()
    end
  end


  # Builds the request from the given params
  @spec req(client(), atom(), Req.url(), keyword()) :: req_response()
  defp req(%__MODULE__{req: req}, method, url, opts) do
    opts = Keyword.merge(opts, method: method, url: url)

    case get_in(opts, [:json, :stream]) do
      true ->
        opts = Keyword.put(opts, :into, send_to(self()))
        task = Task.async(Req, :request, [req, opts])
        {:ok, Stream.resource(fn -> task end, &stream_next/1, &stream_end/1)}

      pid when is_pid(pid) ->
        opts =
          opts
          |> Keyword.update!(:json, & Map.put(&1, :stream, true))
          |> Keyword.put(:into, send_to(pid))
        {:ok, Task.async(Req, :request, [req, opts])}

      _ ->
        Req.request(req, opts)
    end
  end

  # Normalizes the response returned from the request
  @spec res(req_response()) :: response()
  defp res({:ok, %Task{} = task}), do: {:ok, task}
  defp res({:ok, enum}) when is_function(enum), do: {:ok, enum}

  defp res({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp res({:ok, %{status: status}}) do
    {:error, Anthropix.HTTPError.exception(status)}
  end

  defp res({:error, error}), do: {:error, error}

  @sse_regex ~r/event:\s*(\w+)\ndata:\s*({.+})\n/

  @sse_events [
    "message_start",
    "content_block_start",
    "content_block_delta",
    "content_block_stop",
    "message_delta",
    "message_stop",
  ]

  # Returns a callback to handle streaming responses
  @spec send_to(pid()) :: fun()
  defp send_to(pid) do
    fn {:data, data}, acc ->
      @sse_regex
      |> Regex.scan(data)
      |> Enum.each(fn
        [_, event, data] when event in @sse_events ->
          data = Jason.decode!(data)
          Process.send(pid, {self(), {:data, data}}, [])
        _event ->
          nil
      end)
      {:cont, acc}
    end
  end

  # Recieve messages into a stream
  defp stream_next(%Task{pid: pid, ref: ref} = task) do
    receive do
      {^pid, {:data, data}} ->
        {[data], task}

      {^ref, {:ok, %Req.Response{status: status}}} when status in 200..299 ->
        {:halt, task}

      {^ref, {:ok, %Req.Response{status: status}}} ->
        raise Anthropix.HTTPError.exception(status)

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
