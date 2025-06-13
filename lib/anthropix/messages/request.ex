defmodule Anthropix.Messages.Request do
  import Peri
  alias Anthropix.{APIError, Message, Tool}
  alias Anthropix.Messages

  @default_max_tokens 4096
  @default_thinking_tokens 1024

  @enforce_keys [:client, :body, :options]
  defstruct [:client, :body, :options]

  @opts_keys [:max_retries, :max_steps]

  @type t() :: %__MODULE__{
    client: Anthropix.client(),
    body: request(),
    options: options(),
  }

  @type request() :: %{
    :model => String.t(),
    :messages => list(Message.t()),
    :max_tokens => non_neg_integer(),
    optional(:system) => String.t() | list(Message.text_content()),
    optional(:tool_choice) => tool_choice(),
    optional(:tools) => list(Tool.t()),
    optional(:thinking) => thinking(),
    optional(:container) => String.t(),
    optional(:mcp_servers) => list(mcp_server()),
    optional(:metadata) => metadata(),
    optional(:service_tier) => String.t(),
    # stream ?? #todo - have sperate methods instead of configurable?
    optional(:stop_sequences) => list(String.t()),
    optional(:temperature) => float(),
    optional(:top_k) => integer(),
    optional(:top_p) => float(),
  }

  @type options() :: %{
    optional(:max_retries) => non_neg_integer(),
    optional(:max_steps) => non_neg_integer()
  }

  @type tool_choice() :: %{
    :type => String.t(),
    optional(:name) => String.t(),
    optional(:disable_parallel_tool_use) => boolean()
  }

  @type mcp_server() :: %{
    :type => String.t(),
    :name => String.t(),
    :url => String.t(),
    optional(:authorization_token) => String.t(),
    optional(:tool_configuration) => %{
      :enabled => boolean(),
      optional(:allowed_tools) => list(String.t())
    }
  }

  @type thinking() :: %{
    :type => String.t(),
    optional(:budget_tokens) => non_neg_integer()
  }

  @type metadata() :: %{
    optional(:user_id) => String.t()
  }

  @type cache_control() :: %{
    type:  String.t(),
    ttl: String.t()
  }

  # Schemas

  defschema :request, %{
    model: {:required, :string},

    # Prompt
    messages: {:required, {:list, {:either, {
      Message.get_schema(:message),
      {:custom, &validate_message/1}
    }}}},
    system: {:either, {
      :string,
      {:list, Message.get_schema(:text_content)}
    }},

    # Tool use
    tool_choice: {:either, {get_schema(:tool_choice), nil}},
    tools: {:list, {:either, {
      Tool.get_schema(:tool),
      {:custom, &validate_tool/1}
    }}},

    # Extended thinking
    thinking: {:either, {get_schema(:thinking), nil}},

    # Misc
    container: :string,
    mcp_servers: {:list, get_schema(:mcp_server)},
    metadata: {:either, {get_schema(:metadata), nil}},
    service_tier: {:enum, ["auto", "standard_only"]},
    # stream - option or manually add based on function?

    # Params
    max_tokens: {{:integer, {:gt, 0}}, {:default, @default_max_tokens}},
    stop_sequences: {:list, :string},
    temperature: {:float, {:range, {0, 1}}},
    top_k: {:integer, {:gte, 1}},
    top_p: {:float, {:range, {0, 1}}},
  }

  defschema :options, %{
    max_retries: {{:integer, {:gte, 0}}, {:default, 2}},
    max_steps: {{:integer, {:gte, 1}}, {:default, 1}}
  }

  # Tool schemas

  defschema :tool_choice, %{
    type: {:required, {:enum, [
      "auto",
      "any",
      "tool",
      "none"
    ]}},
    name: {:cond, &tool_choice_is_tool/1, {:required, :string}, nil},
    disable_parallel_tool_use: :boolean
  }

  defschema :tool, %{
    type: {:literal, "custom"},
    name: {:required, :string},
    description: :string,
    input_schema: :map,
    cache_control: {:either, {get_schema(:cache_control), nil}},
  }

  defschema :mcp_server, %{
    type: {:required, {:literal, "url"}},
    name: {:required, :string},
    url: {:required, :string},
    authorization_token: :string,
    tool_configuration: %{
      enabled: :boolean,
      allowed_tools: {:list, :string}
    },
  }

  # Other schemas

  defschema :thinking, %{
    type: {:enum, ["enabled", "disabled"]},
    budget_tokens: {:cond, &thinking_is_enabled/1, {{:integer, {:gte, 1024}}, {:default, @default_thinking_tokens}}, nil}
  }

  defschema :metadata, %{
    user_id: {:string, {:max, 256}}
  }

  defschema :cache_control, %{
    type: {:required, {:literal, "ephemeral"}},
    ttl: {:enum, ["5m", "1h"]}
  }

  # Functions

  @spec new(client :: Anthropix.client(), params :: map() | keyword()) :: {:ok, t()} | {:error, any()}
  def new(%Anthropix{} = client, params) when is_map(params) or is_list(params) do
    {opts, params} = split_keys(params, @opts_keys)
    with {:ok, body} <- request(params),
         {:ok, opts} <- options(opts)
    do
      {:ok, struct(__MODULE__, client: client, body: body, options: opts)}
    end
  end

  @spec new!(client :: Anthropix.client(), params :: map() | keyword()) :: t()
  def new!(%Anthropix{} = client, params) when is_map(params) or is_list(params) do
    {opts, params} = split_keys(params, @opts_keys)
    body = request!(params)
    opts = options!(opts)
    struct!(__MODULE__, client: client, body: body, options: opts)
  end

  @spec call(request :: t()) :: {:ok, Messages.Response.t()} | {:error, term()}
  def call(%__MODULE__{client: client, body: body}) do
    case Req.post(client.req, url: "/messages", json: body) do
      {:ok, %{status: status} = res} when status in 200..299 ->
        Messages.Response.new(res)
      {:ok, res} ->
        {:error, APIError.exception(res)}
      {:error, error} ->
        {:error, error}
    end
  end

  @spec call!(request :: t()) :: Messages.Response.t()
  def call!(%__MODULE__{} = request) do
    case call(request) do
      {:ok, response} -> response
      {:error, error} -> raise error
    end
  end

  @spec stream(request :: t()) :: Messages.StreamingResponse.t()
  def stream(%__MODULE__{client: client, body: body}) do
    client.req
    |> Req.merge(url: "/messages", json: Map.put(body, :stream, true))
    |> Messages.StreamingResponse.init()
  end

  # Helpers

  @spec split_keys(input :: map() | keyword(), keys :: list(atom())) :: {map(), map()} | {keyword(), keyword()}
  defp split_keys(input, keys) when is_map(input), do: Map.split(input, keys)
  defp split_keys(input, keys) when is_list(input), do: Keyword.split(input, keys)

  @spec tool_choice_is_tool(data :: any()) :: boolean()
  defp tool_choice_is_tool(%{tool_choice: %{type: "tool"}}), do: true
  defp tool_choice_is_tool(_data), do: false

  @spec thinking_is_enabled(data :: any()) :: boolean()
  defp thinking_is_enabled(%{thinking: %{type: "enabled"}}), do: true
  defp thinking_is_enabled(_data), do: false

  @spec validate_message(val :: any()) :: :ok | {:error, term(), keyword()}
  defp validate_message(%Message{}), do: :ok
  defp validate_message(val), do: {:error, "Invalid message. Expected %Message{} but got %{val}", [val: val]}

  @spec validate_tool(val :: any()) :: :ok | {:error, term(), keyword()}
  defp validate_tool(%Tool{}), do: :ok
  defp validate_tool(val), do: {:error, "Invalid tool. Expected %Tool{} but got %{val}", [val: val]}

end
