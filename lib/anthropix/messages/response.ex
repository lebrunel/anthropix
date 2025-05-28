defmodule Anthropix.Messages.Response do
  import Peri
  import Anthropix.Utils.MapUtils, only: [safe_atomize_keys: 1]

  defstruct [:id, :type, :role, :content, :model, :stop_reason, :stop_sequence, :usage, :container]

  @type t() :: %__MODULE__{
    id: String.t(),
    type: String.t(),
    role: String.t(),
    content: list(), # todo typespecs for message conttent blocks
    model: String.t(),
    stop_reason: String.t() | nil,
    stop_sequence: String.t() | nil,
    usage: usage(),
    container: map() | nil
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
    content: {:required, {:list, :map}}, # todo peri schemas for content blocks
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

  @spec new(data :: map()) :: {:ok, t()} | {:error, term()}
  def new(data) when is_map(data) do
    with {:ok, params} <- response(safe_atomize_keys(data)) do
      {:ok, struct(__MODULE__, params)}
    end
  end

  @spec new!(data :: map()) :: t()
  def new!(data) when is_map(data) do
    struct!(__MODULE__, response!(safe_atomize_keys(data)))
  end

end
