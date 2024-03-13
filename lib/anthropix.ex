defmodule Anthropix do
  @version Keyword.fetch!(Mix.Project.config(), :version)
  @moduledoc """
  ![License](https://img.shields.io/github/license/lebrunel/anthropix?color=informational)

  Anthropix is an open-source Elixir client for the Anthropic API, providing a
  simple and convenient way to integrate Claude, Anthropic's powerful language
  model, into your applications.

  - ✅ API client fully implementing the [Anthropic API](https://docs.anthropic.com/claude/reference/getting-started-with-the-api)
  - 🛜 Streaming API requests
    - Stream to an Enumerable
    - Or stream messages to any Elixir process
  - 🕶️ Powerful yet painless function calling with **Agents**

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

  For more examples, refer to the [Anthropix documentation](https://hexdocs.pm/anthropix).

  ### Initiate a client.

  See `Anthropix.init/2`.

  ```elixir
  iex> client = Anthropix.init(api_key)
  ```

  ### Chat with Claude

  See `Anthropix.chat/2`.

  ```elixir
  iex> messages = [
  ...>   %{role: "system", content: "You are a helpful assistant."},
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

  ## Function calling

  Chatting with Claude is nice and all, but when it comes to function calling,
  Anthropix has a trick up its sleeve. Meet `Anthropix.Agent`.

  The Agent module abstracts away all the rough bits of implementing
  [Anthropic style function calling](https://docs.anthropic.com/claude/docs/functions-external-tools),
  leaving a delightfully simple API that opens the doors to powerful and
  advanced agent workflows.

  ```elixir
  iex> ticker_tool = %Anthropix.Tool.new([
  ...>   name: "get_ticker_symbol",
  ...>   description: "Gets the stock ticker symbol for a company searched by name. Returns str: The ticker symbol for the company stock. Raises TickerNotFound: if no matching ticker symbol is found.",
  ...>   params: [
  ...>     %{name: "company_name", description: "The name of the company.", type: "string"}
  ...>   ],
  ...>   function: &MyStocks.get_ticker/1
  ...> ])

  iex> price_tool = %Anthropix.Tool.new([
  ...>   name: "get_current_stock_price",
  ...>   description: "Gets the current stock price for a company. Returns float: The current stock price. Raises ValueError: if the input symbol is invalid/unknown.",
  ...>   params: [
  ...>     %{name: "symbol", description: "The stock symbol of the company to get the price for.", type: "string"}
  ...>   ],
  ...>   function: &MyStocks.get_price/1
  ...> ])

  iex> agent = Anthropix.Agent.init(
  ...>   Anthropix.init(api_key),
  ...>   [ticker_tool, price_tool]
  ...> )

  iex> Anthropix.Agent.chat(agent, [
  ...>   model: "claude-3-sonnet-20240229",
  ...>   system: "Answer like Snoop Dogg.",
  ...>   messages: [
  ...>     %{role: "user", content: "What is the current stock price of General Motors?"}
  ...>   ]
  ...> ])
  %{
    result: %{
      "content" => [%{
        "type" => "text",
        "text" => "*snaps fingers* Damn shawty, General Motors' stock is sittin' pretty at $39.21 per share right now. Dat's a fly price for them big ballers investin' in one of Detroit's finest auto makers, ya heard? *puts hands up like car doors* If ya askin' Snoop, dat stock could be rollin' on some dubs fo' sho'. Just don't get caught slippin' when them prices dippin', ya dig?"
      }]
    }
  }
  ```

  For a more detailed walkthrough, refer to the `Anthropix.Agent` documentation.
  """
  use Anthropix.Schemas
  alias Anthropix.{APIError, Tool, XML}

  defstruct [:req]

  @typedoc "Client struct"
  @type client() :: %__MODULE__{
    req: Req.Request.t()
  }


  schema :message_content, [
    type: [type: :string, required: true],
    text: [type: :string],
    source: [type: :map, keys: [
      type: [type: :string, required: :true],
      media_type: [type: :string, required: :true],
      data: [type: :string, required: :true],
    ]]
  ]

  schema :chat_message, [
    role: [
      type: :string,
      required: true,
      doc: "The role of the message, either `user` or `assistant`."
    ],
    content: [
      type: {:or, [:string, {:list, {:map, schema(:message_content).schema}}]},
      required: true,
      doc: "Message content, either a single string or an array of content blocks."
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
  @type content_block() :: %{
    :type => String.t(),
    optional(:text) => String.t(),
    optional(:source) => %{
      type: String.t(),
      media_type: String.t(),
      data: String.t(),
    }
  }

  @typedoc "Client response"
  @type response() ::
    {:ok, map() | Enumerable.t() | Task.t()} |
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
    tools: [
      type: {:list, {:struct, Tool}},
      doc: "A list of tools the model may call.",
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
  Chat with Claude. Send a list of structured input messages with text and/or
  image content, and Claude will generate the next message in the conversation.

  ## Options

  #{doc(:chat)}

  ## Message structure

  Each message is a map with the following fields:

  #{doc(:chat_message)}

  ## Examples

  ```elixir
  iex> messages = [
  ...>   %{role: "system", content: "You are a helpful assistant."},
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
      params =
        params
        |> use_tools()
        |> Enum.into(%{})

      client
      |> req(:post, "/messages", json: params)
      |> res()
    end
  end


  # If the params contains tools, setup the system prompt and stop sequnces
  @spec use_tools(keyword()) :: keyword()
  defp use_tools(params) do
    case Keyword.get(params, :tools) do
      tools when is_list(tools) and length(tools) > 0 ->
        prompt = """
        In this environment you have access to a set of tools you can use to answer the user's question.

        You may call them like this:

        <function_calls>
          <invoke>
            <tool_name>$TOOL_NAME</tool_name>
            <parameters>
              <$PARAMETER_NAME>$PARAMETER_VALUE</$PARAMETER_NAME>
              ...
            </parameters>
          </invoke>
        </function_calls>

        Here are the tools available:

        #{XML.encode(:tools, tools)}
        """
        stop = "</function_calls>"
        params
        |> Keyword.delete(:tools)
        |> Keyword.update(:stop_sequences, [stop], & [stop | &1])
        |> Keyword.update(:system, prompt, & prompt <> "\n" <> &1)

      _ ->
        params
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

  defp res({:ok, %{body: body}}) do
    {:error, APIError.exception(body)}
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

end
