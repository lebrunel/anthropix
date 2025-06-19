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
  alias Anthropix.{Messages, StreamingResponse}

  defstruct [:req]

  @typedoc "Client struct"
  @type client() :: %__MODULE__{
    req: Req.Request.t()
  }

  @typedoc "Legacy chat response"
  @type legacy_response() ::
    {:ok, map() | Enumerable.t() | Task.t()} |
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


  @doc """
  Chat with Claude. Send a list of structured input messages with text and/or
  image content, and Claude will generate the next message in the conversation.

  ## Options

  {doc(:chat)}

  ## Message structure

  Each message is a map with the following fields:

  {doc(:chat_message)}

  ## Tool structure

  Each tool is a map with the following fields:

  {doc(:chat_tool)}

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
  @deprecated "use XXX instead" # todo update deprecation warning
  @spec chat(client(), keyword()) :: legacy_response()
  def chat(%__MODULE__{} = client, params \\ []) do
    with {:ok, request} <- Messages.Request.new(client, params) do
      case Enum.into(params, %{}) |> Map.get(:stream) do
        pid when is_pid(pid) ->
          task = Task.async(fn ->
            streaming =
              request
              |> Messages.Request.stream()
              |> StreamingResponse.on(:data, & send(pid, {self(), {:data, &1}}))

            with {:ok, res} <- StreamingResponse.run(streaming) do
              {:ok, get_in(res.raw.body)}
            end
          end)
          {:ok, task}

        true ->
          stream =
            request
            |> Messages.Request.stream()
            |> StreamingResponse.stream()
          {:ok, stream}

        _ ->
          with {:ok, res} <- Messages.Request.call(request) do
            {:ok, get_in(res.raw.body)}
          end
      end
    end
  end


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

end
