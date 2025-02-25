# Anthropix

![Anthropix](https://raw.githubusercontent.com/lebrunel/anthropix/main/media/poster.webp)

![Hex.pm](https://img.shields.io/hexpm/v/anthropix?color=informational)
![License](https://img.shields.io/github/license/lebrunel/anthropix?color=informational)
![Build Status](https://img.shields.io/github/actions/workflow/status/lebrunel/anthropix/elixir.yml?branch=main)

Anthropix is an open-source Elixir client for the Anthropic API, providing a simple and convenient way to integrate Claude, Anthropic's powerful language model, into your applications.

- ✅ API client fully implementing the [Anthropic API](https://docs.anthropic.com/claude/reference/getting-started-with-the-api)
- 🧰 Tool use (function calling)
- 🧠 Extended thinking
- ⚡ Prompt caching
- 📦 Message batching
- 🛜 Streaming API requests
  - Stream to an Enumerable
  - Or stream messages to any Elixir process

## Installation

The package can be installed by adding `anthropix` to your list of dependencies in `mix.exs`.

```elixir
def deps do
  [
    {:anthropix, "~> 0.6"}
  ]
end
```

## Quickstart

> [!NOTE]
> #### Beta features
>
> Anthropic frequently ship new features under a beta flag, requiring headers to be added to your requests to take advantage of the feature.
>
> If required, beta headers can be added with `init/2`.
>
> ```elixir
> client = Anthropix.init(beta: ["output-128k-2025-02-19"])
> ```

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

## License

This package is open source and released under the [Apache-2 License](https://github.com/lebrunel/ollama/blob/master/LICENSE).

© Copyright 2024 [Push Code Ltd](https://www.pushcode.com/).
