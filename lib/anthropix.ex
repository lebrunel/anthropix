defmodule Anthropix do
  @version Keyword.fetch!(Mix.Project.config(), :version)
  @moduledoc """
  ![Anthropix](https://raw.githubusercontent.com/lebrunel/anthropix/main/media/poster.webp)

  ![License](https://img.shields.io/github/license/lebrunel/anthropix?color=informational)

  Anthropix is an open-source Elixir client for the Anthropic API, providing a
  simple and convenient way to integrate Claude, Anthropic's powerful language
  model, into your applications.

  - ✅ API client fully implementing the [Anthropic API](https://docs.anthropic.com/claude/reference/getting-started-with-the-api)
  - 🧰 Tool use (function calling)
  - 🧠 Extended thinking
  - ⚡ Prompt caching
  - 📦 Message batching (`Anthropix.Batch`)
  - 🛜 Streaming API requests
    - Stream to an Enumerable
    - Or stream messages to any Elixir process

  ## Installation

  The package can be installed by adding `anthropix` to your list of
  dependencies in `mix.exs`.

  ```elixir
  def deps do
    [
      {:anthropix, "~> #{@version}"}
    ]
  end
  ```

  ## Quickstart

  > #### Beta features {: .info}
  >
  > Anthropic frequently ship new features under a beta flag, requiring headers
  to be added to your requests to take advantage of the feature.
  >
  > If required, beta headers can be added with `init/2`.
  >
  > ```elixir
  > client = Anthropix.init(beta: ["output-128k-2025-02-19"])
  > ```

  ### Initiate a client.

  See `Anthropix.init/2`.

  ```elixir
  iex> client = Anthropix.init(api_key)
  ```

  ### Chat with Claude

  See `Anthropix.chat/2`.

  ```elixir
  iex> messages = [
  ...>   %{role: "user", content: "Why is the sky blue?"},
  ...>   %{role: "assistant", content: "Due to rayleigh scattering."},
  ...>   %{role: "user", content: "How is that different than mie scattering?"},
  ...> ]

  iex> Anthropix.chat(client, [
  ...>   model: "claude-3-opus-20240229",
  ...>   messages: messages,
  ...> ])
  {:ok, %{"content" => [%{
    "type" => "text",
    "text" => "Mie scattering affects all wavelengths similarly, while Rayleigh favors shorter ones."
  }], ...}}
  ```

  ### Streaming

  A streaming request can be initiated by setting the `:stream` option.

  When `:stream` is true a lazy `t:Enumerable.t/0` is returned which can be used
  with any `Stream` functions.

  ```elixir
  iex> {:ok, stream} = Anthropix.chat(client, [
  ...>   model: "claude-3-opus-20240229",
  ...>   messages: messages,
  ...>   stream: true,
  ...> ])
  {:ok, #Function<52.53678557/2 in Stream.resource/3>}

  iex> stream
  ...> |> Stream.each(&update_ui_with_chunk/1)
  ...> |> Stream.run()
  :ok
  ```

  Because the above approach builds the `t:Enumerable.t/0` by calling `receive`,
  using this approach inside GenServer callbacks may cause the GenServer to
  misbehave. Setting the `:stream` option to a `t:pid/0` returns a `t:Task.t/0`
  which will send messages to the specified process.
  """
  use Anthropix.Schemas
  alias Anthropix.APIError

  defstruct [:req]

  @typedoc "Client struct"
  @type client() :: %__MODULE__{
    req: Req.Request.t()
  }

  @permissive_map {:map, {:or, [:atom, :string]}, :any}

  schema :chat_message, [
    role: [
      type: :string,
      required: true,
      doc: "The role of the message, either `user` or `assistant`."
    ],
    content: [
      type: {:or, [:string, {:list, @permissive_map}]},
      required: true,
      doc: "Message content, either a single string or an array of content blocks."
    ],
  ]

  schema :chat_tool, [
    name: [
      type: :string,
      required: true,
      doc: "Name of the tool."
    ],
    description: [
      type: :string,
      required: true,
      doc: "Description of the tool"
    ],
    input_schema: [
      type: @permissive_map,
      required: true,
      doc: "JSON schema for the tool input shape that the model will produce in tool_use output content blocks."
    ],
    cache_control: [
      type: @permissive_map,
      doc: "Cache-control parameter."
    ]
  ]

  schema :chat_tool_choice, [
    type: [
      type: :string,
      required: true,
      doc: "One of `auto`, `any` or `tool`."
    ],
    name: [
      type: :string,
      doc: "The name of the tool to use."
    ],
    disable_parallel_tool_use: [
      type: :boolean
    ]
  ]

  @typedoc """
  Chat message

  A chat message is a `t:map/0` with the following fields:

  #{doc(:chat_message)}
  """
  @type message() :: %{
    role: String.t(),
    content: String.t() | list(content_block())
  }

  @typedoc "Message content block."
  @type content_block() ::
    content_text() |
    content_media() |
    content_tool_use() |
    content_tool_result()

  @type content_text() :: %{
    type: String.t(),
    text: String.t()
  }

  @type content_media() :: %{
    type: String.t(),
    source: %{
      type: String.t(),
      media_type: String.t(),
      data: String.t(),
    }
  }

  @type content_tool_use() :: %{
    type: String.t(),
    id: String.t(),
    name: String.t(),
    input: %{optional(String.t()) => String.t()}
  }

  @type content_tool_result() :: %{
    type: String.t(),
    tool_use_id: String.t(),
    content: %{optional(String.t()) => String.t()}
  }

  @typedoc """
  Tool.

  A chat tool is a `t:map/0` with the following fields:

  #{doc(:chat_tool)}
  """
  @type tool() :: %{
    name: String.t(),
    description: String.t(),
    input_schema: input_schema(),
  }

  @typedoc "JSON schema for the tool `input` shape."
  @type input_schema() :: %{
    :type => String.t(),
    :properties => %{
      optional(String.t()) => %{
        optional(:enum) => list(String.t()),
        type: String.t(),
        description: String.t(),
      }
    },
    optional(:required) => list(String.t())
  }

  @typedoc "Client response"
  @type response() ::
    {:ok, map() | Enumerable.t() | Task.t()} |
    {:error, term()}

  @typedoc false
  @type req_response() ::
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

  # Current none active by default
  @default_beta_tokens []

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

  ##

  ## Examples

  ```elixir
  iex> client = Anthropix.init("sk-ant-your-key", receive_timeout: :infinity)
  %Anthropix{}
  ```
  """
  @spec init(String.t(), keyword()) :: client()
  def init(api_key, opts \\ []) when is_binary(api_key) do
    {headers, opts} = pop_headers(opts)

    req = @default_req_opts
    |> Keyword.merge(opts)
    |> Req.new()
    |> Req.Request.put_header("x-api-key", api_key)
    |> Req.Request.put_headers(headers)

    struct(__MODULE__, req: req)
  end


  schema :chat, [
    model: [
      type: :string,
      required: true,
      doc: "The model that will complete your prompt.",
    ],
    messages: [
      type: {:list, {:map, schema(:chat_message).schema}},
      required: true,
      doc: "Input messages.",
    ],
    system: [
      type: {:or, [:string, {:list, @permissive_map}]},
      doc: "System prompt.",
    ],
    thinking: [
      type: :map,
      keys: [
        type: [type: {:in, ["enabled"]}],
        budget_tokens: [type: :non_neg_integer]
      ],
      doc: "Enable thinking mode and the budget of tokens to use."
    ],
    max_tokens: [
      type: :integer,
      default: 4096,
      doc: "The maximum number of tokens to generate before stopping.",
    ],
    metadata: [
      type: @permissive_map,
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
    tools: [
      type: {:list, {:map, schema(:chat_tool).schema}},
      doc: "A list of tools the model may call.",
    ],
    tool_choice: [
      type: :map,
      keys: schema(:chat_tool_choice).schema,
      doc: "How to use the provided tools."
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
  Chat with Claude. Send a list of structured input messages with text and/or
  image content, and Claude will generate the next message in the conversation.

  ## Options

  #{doc(:chat)}

  ## Message structure

  Each message is a map with the following fields:

  #{doc(:chat_message)}

  ## Tool structure

  Each tool is a map with the following fields:

  #{doc(:chat_tool)}

  ## Examples

  ```elixir
  iex> messages = [
  ...>   %{role: "user", content: "Why is the sky blue?"},
  ...>   %{role: "assistant", content: "Due to rayleigh scattering."},
  ...>   %{role: "user", content: "How is that different than mie scattering?"},
  ...> ]

  iex> Anthropix.chat(client, [
  ...>   model: "claude-3-opus-20240229",
  ...>   messages: messages,
  ...> ])
  {:ok, %{"content" => [%{
    "type" => "text",
    "text" => "Mie scattering affects all wavelengths similarly, while Rayleigh favors shorter ones."
  }], ...}}

  # Passing true to the :stream option initiates an async streaming request.
  iex> Anthropix.chat(client, [
  ...>   model: "claude-3-opus-20240229",
  ...>   messages: messages,
  ...>   stream: true,
  ...> ])
  {:ok, #Function<52.53678557/2 in Stream.resource/3>}
  ```
  """
  @spec chat(client(), keyword()) :: response()
  def chat(%__MODULE__{} = client, params \\ []) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:chat)) do
      client
      |> req(:post, "/messages", json: Enum.into(params, %{}))
      |> res()
    end
  end

  # Builds the request from the given params
  @spec req(client(), atom(), Req.url(), keyword()) :: req_response()
  defp req(%__MODULE__{req: req}, method, url, opts) do
    opts = Keyword.merge(opts, method: method, url: url)
    stream_opt = get_in(opts, [:json, :stream])
    dest = if is_pid(stream_opt), do: stream_opt, else: self()

    if stream_opt do
      opts =
        opts
        |> Keyword.update!(:json, & Map.put(&1, :stream, true))
        |> Keyword.put(:into, stream_handler(dest))

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
  @spec res(req_response()) :: response()
  defp res({:ok, %Task{} = task}), do: {:ok, task}
  defp res({:ok, enum}) when is_function(enum), do: {:ok, enum}
  defp res({:ok, %{status: status, body: ""} = response}) when status in 200..299,
    do: {:ok, response.body}
  defp res({:ok, %{status: status, body: body}}) when status in 200..299,
    do: {:ok, body}
  defp res({:ok, resp}),
    do: {:error, APIError.exception(resp)}
  defp res({:error, error}), do: {:error, error}

  # Pop headers out of options given to init/2
  @spec pop_headers(keyword()) :: {list(), keyword()}
  defp pop_headers(opts) do
    {headers, opts} = Keyword.pop(opts, :headers, [])
    case Keyword.pop(opts, :beta, @default_beta_tokens) do
      {[], opts} -> {headers, opts}
      {betas, opts} when is_list(betas) ->
        {headers ++ [{"anthropic-beta", Enum.join(betas, ",")}], opts}
      {betas, opts} when is_binary(betas) ->
        {headers ++ [{"anthropic-beta", betas}], opts}
      _ -> {headers, opts}
    end
  end

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
  @spec stream_handler(pid()) :: fun()
  defp stream_handler(pid) do
    fn {:data, data}, {req, res} ->
      res =
        @sse_regex
        |> Regex.scan(data)
        |> Enum.filter(& match?([_, event, _data] when event in @sse_events, &1))
        |> Enum.map(fn [_, _event, data] -> Jason.decode!(data) end)
        |> Enum.reduce(res, fn data, res ->
          Process.send(pid, {self(), {:data, data}}, [])
          stream_merge(res, data)
        end)

      {:cont, {req, res}}
    end
  end

  # Merges streaming message responses
  @spec stream_merge(Req.Response.t(), map()) :: Req.Response.t()
  defp stream_merge(res, %{"type" => "message_start", "message" => message}),
    do: put_in(res.body, message)

  defp stream_merge(res, %{"type" => "content_block_start", "index" => i, "content_block" => block}) do
    update_in(res.body, fn body ->
      update_in(body, ["content"], & List.insert_at(&1, i, block))
    end)
  end

  defp stream_merge(res, %{"type" => "content_block_delta", "index" => i, "delta" => %{"type" => "text_delta"} = delta}) do
    update_in(res.body, fn body ->
      update_in(body, ["content"], fn content ->
        List.update_at(content, i, fn block ->
          update_in(block, ["text"], & &1 <> delta["text"])
        end)
      end)
    end)
  end

  defp stream_merge(res, %{"type" => "content_block_delta", "index" => i, "delta" => %{"type" => "input_json_delta"} = delta}) do
    update_in(res.body, fn body ->
      update_in(body, ["content"], fn content ->
        List.update_at(content, i, fn block ->
          update_in(block, ["input"], fn input ->
            case input do
              nil -> %{"_partial_json" => delta["partial_json"]}
              %{"_partial_json" => existing} -> %{"_partial_json" => existing <> delta["partial_json"]}
              _ -> %{"_partial_json" => delta["partial_json"]}
            end
          end)
        end)
      end)
    end)
  end

  defp stream_merge(res, %{"type" => "message_delta", "delta" => delta}),
    do: update_in(res.body, & Map.merge(&1, delta))

  defp stream_merge(res, %{"type" => "content_block_stop", "index" => i}) do
    update_in(res.body, fn body ->
      update_in(body, ["content"], fn content ->
        List.update_at(content, i, fn block ->
          case get_in(block, ["input", "_partial_json"]) do
            nil -> block
            "" -> block  # Handle empty JSON string
            json_str ->
              input = json_str |> Jason.decode!()
              put_in(block, ["input"], input)
          end
        end)
      end)
    end)
  end

  defp stream_merge(res, _data), do: res

  # Recieve messages into a stream
  defp stream_next(%Task{pid: pid, ref: ref} = task) do
    receive do
      {^pid, {:data, data}} ->
        {[data], task}

      {^ref, {:ok, %Req.Response{status: status}}} when status in 200..299 ->
        {:halt, task}

      {^ref, {:ok, %Req.Response{body: body}}} ->
        raise APIError.exception(body)

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

  @doc false
  def chat_schema, do: schema(:chat).schema

end
