defmodule Anthropix.Agent do
  @moduledoc """
  The `Anthropix.Agent` module makes function calling with Claude a breeze!

  Whilst it's possible to manually implement function calling using
  `Anthropix.chat/2`, this module provides an interface on top that automates
  the entire flow. Function calling is reduced to the following steps.

  1. **Defining functions** - define one or more functions through
  `Anthropix.Tool.new/1`.
  2. **Initialise the agent** - initialise the agent by passing a
  `t:Anthropix.client/0` client and list of tools to `init/2`
  3. **Chat with Claude** - chat with Clause just how you normally would, using
  `chat/2`. Where Claude attempts to call functions, Anthropix will handle that
  automatically, send the result back to Claude, iterating as many times as is
  necessary before ultimately a final result is returned.

  `chat/2` returns a `t:t/0` struct, which contains a list of all
  messages, a sum of all usage statistics, as well as the final response.

  ## Example

  Define your functions as tools. Remember, we're working with language models,
  so provide clear descriptions for the functions and their parameters.

  ```elixir
  iex> ticker_tool = %Anthropix.Tool.new([
  ...>   name: "get_ticker_symbol",
  ...>   description: "Gets the stock ticker symbol for a company searched by name. Returns str: The ticker symbol for the company stock. Raises TickerNotFound: if no matching ticker symbol is found.",
  ...>   params: [
  ...>     %{name: "company_name", description: "The name of the company.", type: "string"}
  ...>   ],
  ...>   function: {MyApp.Repo, :get_ticker, []}
  ...> ])

  iex> price_tool = %Anthropix.Tool.new([
  ...>   name: "get_current_stock_price",
  ...>   description: "Gets the current stock price for a company. Returns float: The current stock price. Raises ValueError: if the input symbol is invalid/unknown.",
  ...>   params: [
  ...>     %{name: "symbol", description: "The stock symbol of the company to get the price for.", type: "string"}
  ...>   ],
  ...>   function: {MyApp.Repo, :get_price, []}
  ...> ])
  ```

  Initialise the agent and chat with it. `chat/2` accepts the same parameters as
  `Anthropix.chat/2` so can be combined with custom system prompts, chat
  history, and any other parameters.

  ```elixir
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

  ## Streaming

  The `:stream` option is currently ignored on `chat/2` in this modlule, so all
  function calling requests are lengthy blocking calls whilst multiple
  sequential requests are occuring behind the scenes.

  This will hopefully change in a future version, but figuring out what and how
  to stream from the multiple requests is less trivial than I'd like it to be.
  """
  alias Anthropix.{FunctionCall, Tool, XML}

  defstruct client: nil,
            tools: [],
            messages: [],
            result: nil,
            usage: nil

  @typedoc "Agent struct"
  @type t() :: %__MODULE__{
    client: Anthropix.client(),
    tools: list(Tool.t()),
    messages: list(map()),
    result: map(),
    usage: map(),
  }

  @doc """
  Creates a new Agent struct from the given `t:Anthropix.client/0` and list of
  tools.
  """
  @spec init(Anthropix.client(), list(Tool.t())) :: t()
  def init(%Anthropix{} = client, tools) do
    struct(__MODULE__, client: client, tools: tools)
  end

  @doc """
  Chat with Claude, using the given agent. Accepts the same parameters as
  `Anthropix.chat/2`.

  Note, the `:stream` option is currently ignored for this function.

  See the example as the [top of this page](#module-example).
  """
  @spec chat(t(), keyword()) :: {:ok, t()} | {:error, term()}
  def chat(%__MODULE__{client: client, tools: tools} = agent, params \\ []) do
    params = Keyword.merge(params, tools: tools, stream: false)

    with {:ok, res} <- Anthropix.chat(client, params) do
      %{"text" => content} = hd(res["content"])

      agent =
        agent
        |> Map.put(:messages, Keyword.get(params, :messages))
        |> Map.update!(:usage, & update_usage(&1, res["usage"]))

      case FunctionCall.extract!(content) do
        [] ->
          {:ok, Map.put(agent, :result, res)}

        functions ->
          functions = FunctionCall.invoke_all(functions, tools)

          params = Keyword.update!(params, :messages, fn messages ->
            messages ++ [
              %{role: "assistant", content: content},
              %{role: "user", content: XML.encode(:function_results, functions)}
            ]
          end)

          chat(agent, params)
      end
    end
  end


  # Merges the new usage stats into the previous
  defp update_usage(nil, new), do: new
  defp update_usage(prev, new) do
    prev
    |> Enum.map(fn {key, val} -> {key, val + Map.get(new, key)} end)
    |> Enum.into(%{})
  end

end
