# Anthropix

![Ollama-ex](https://raw.githubusercontent.com/lebrunel/anthropix/main/media/poster.webp)

![Hex.pm](https://img.shields.io/hexpm/v/anthropix?color=informational)
![License](https://img.shields.io/github/license/lebrunel/anthropix?color=informational)
![Build Status](https://img.shields.io/github/actions/workflow/status/lebrunel/anthropix/elixir.yml?branch=main)

Anthropix is an open-source Elixir client for the Anthropic API, providing a simple and convenient way to integrate Claude, Anthropic's powerful language model, into your applications.

- ✅ API client fully implementing the [Anthropic API](https://docs.anthropic.com/claude/reference/getting-started-with-the-api)
- 🛜 Streaming API requests
  - Stream to an Enumerable
  - Or stream messages to any Elixir process
- 😎 Powerful yet painless function calling with **Agents**

## Installation

The package can be installed by adding `anthropix` to your list of dependencies in `mix.exs`.

```elixir
def deps do
  [
    {:anthropix, "~> 0.1"}
  ]
end
```

## Quickstart

For more examples, refer to the [Anthropix documentation](https://hexdocs.pm/anthropix).

### Initiate a client.

See `Anthropix.init/2`.

```elixir
client = Anthropix.init(api_key)
```

### Chat with Claude

See `Anthropix.chat/2`.

```elixir
messages = [
  %{role: "system", content: "You are a helpful assistant."},
  %{role: "user", content: "Why is the sky blue?"},
  %{role: "assistant", content: "Due to rayleigh scattering."},
  %{role: "user", content: "How is that different than mie scattering?"},
]

Anthropix.chat(client, [
  model: "claude-3-opus-20240229",
  messages: messages,
])
# {:ok, %{"content" => [%{
#   "type" => "text",
#   "text" => "Mie scattering affects all wavelengths similarly, while Rayleigh favors shorter ones."
# }], ...}}
```

### Streaming

A streaming request can be initiated by setting the `:stream` option.

When `:stream` is true a lazy `t:Enumerable.t/0` is returned which can be used with any `Stream` functions.

```elixir
{:ok, stream} = Anthropix.chat(client, [
  model: "claude-3-opus-20240229",
  messages: messages,
  stream: true,
])
# {:ok, #Function<52.53678557/2 in Stream.resource/3>}

stream
|> Stream.each(&update_ui_with_chunk/1)
|> Stream.run()
# :ok
```

Because the above approach builds the `t:Enumerable.t/0` by calling `receive`, using this approach inside GenServer callbacks may cause the GenServer to misbehave. Setting the `:stream` option to a `t:pid/0` returns a `t:Task.t/0` which will send messages to the specified process.

## Function calling

Chatting with Claude is nice and all, but when it comes to function calling, Anthropix has a trick up its sleeve. Meet `Anthropix.Agent`.

The Agent module abstracts away all the rough bits of implementing [Anthropic style function calling](https://docs.anthropic.com/claude/docs/functions-external-tools), leaving a delightfully simple API that opens the doors to powerful and advanced agent workflows.

```elixir
ticker_tool = %Anthropix.Tool.new([
  name: "get_ticker_symbol",
  description: "Gets the stock ticker symbol for a company searched by name. Returns str: The ticker symbol for the company stock. Raises TickerNotFound: if no matching ticker symbol is found.",
  params: [
    %{name: "company_name", description: "The name of the company.", type: "string"}
  ],
  function: &MyStocks.get_ticker/1
])

price_tool = %Anthropix.Tool.new([
  name: "get_current_stock_price",
  description: "Gets the current stock price for a company. Returns float: The current stock price. Raises ValueError: if the input symbol is invalid/unknown.",
  params: [
    %{name: "symbol", description: "The stock symbol of the company to get the price for.", type: "string"}
  ],
  function: &MyStocks.get_price/1
])

agent = Anthropix.Agent.init(
  Anthropix.init(api_key),
  [ticker_tool, price_tool]
)

Anthropix.Agent.chat(agent, [
  model: "claude-3-sonnet-20240229",
  system: "Answer like Snoop Dogg.",
  messages: [
    %{role: "user", content: "What is the current stock price of General Motors?"}
  ]
])
# %{
#   result: %{
#     "content" => [%{
#       "type" => "text",
#       "text" => "*snaps fingers* Damn shawty, General Motors' stock is sittin' pretty at $39.21 per share right now. Dat's a fly price for them big ballers investin' in one of Detroit's finest auto makers, ya heard? *puts hands up like car doors* If ya askin' Snoop, dat stock could be rollin' on some dubs fo' sho'. Just don't get caught slippin' when them prices dippin', ya dig?"
#     }]
#   }
# }
```

For a more detailed walkthrough, refer to the `Anthropix.Agent` documentation.

# License

This package is open source and released under the [Apache-2 License](https://github.com/lebrunel/ollama/blob/master/LICENSE).

© Copyright 2024 [Push Code Ltd](https://www.pushcode.com/).
