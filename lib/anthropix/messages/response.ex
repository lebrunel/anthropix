defmodule Anthropix.Messages.Response do
  import Peri
  import Anthropix.Util.MapUtils, only: [safe_atomize_keys: 1]
  alias Anthropix.Message

  defstruct [
    :id,
    :type,
    :role,
    :content,
    :model,
    :stop_reason,
    :stop_sequence,
    :usage,
    :container,
    :raw
  ]

  @type t() :: %__MODULE__{
    id: String.t(),
    type: String.t(),
    role: String.t(),
    content: list(Message.content_block()),
    model: String.t(),
    stop_reason: String.t() | nil,
    stop_sequence: String.t() | nil,
    usage: usage(),
    container: map() | nil,
    raw: Req.Response.t() | nil
  }

  @type container() :: %{
    id: String.t(),
    expires_at: String.t(),
  }

  @type usage() :: %{
    :input_tokens => integer(),
    :output_tokens => integer(),
    optional(:cache_creation) => map(),
    optional(:cache_creation_input_tokens) => integer(),
    optional(:cache_read_input_tokens) => integer(),
    optional(:server_tool_use) => map(),
    optional(:service_tier) => String.t()
  }

  defschema :response, %{
    id: {:required, :string},
    type: {:required, {:literal, "message"}},
    role: {:required, {:literal, "assistant"}},
    content: {:required, {:list, Message.get_schema(:content_block)}},
    model: {:required, :string},
    stop_reason: :string,
    stop_sequence: :string,
    usage: {:required, get_schema(:usage)},
    container: {:either, {get_schema(:container), nil}}
  }

  defschema :container, %{
    id: {:required, :string},
    expires_at: {:required, :string}
  }

  defschema :usage, %{
    input_tokens: {:required, :integer},
    output_tokens: {:required, :integer},
    cache_creation: :map,
    cache_creation_input_tokens: :integer,
    cache_read_input_tokens: :integer,
    server_tool_use: :map,
    service_tier: :string
  }

  @spec new(params :: Req.Response.t() | map()) :: {:ok, t()} | {:error, term()}
  def new(%Req.Response{body: body} = raw) do
    with {:ok, response} <- new(body) do
      {:ok, %{response | raw: raw}}
    end
  end

  def new(params) when is_map(params) do
    with {:ok, params} <- response(safe_atomize_keys(params)) do
      {:ok, struct(__MODULE__, params)}
    end
  end

  @spec new!(params :: Req.Response.t() | map()) :: t()
  def new!(%Req.Response{body: body} = raw) do
    new!(body) |> Map.put(:raw, raw)
  end

  def new!(params) when is_map(params) do
    struct!(__MODULE__, response!(safe_atomize_keys(params)))
  end

end
