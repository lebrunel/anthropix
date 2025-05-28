defmodule Anthropix.Message do
  import Peri

  defstruct [:role, :content]

  @type t() :: %__MODULE__{
    role: String.t(),
    content: list(content_block())
  }

  @type content_block() ::
    text_content() |
    image_content() |
    document_content() |
    thinking() |
    redacted_thinking() |
    tool_use() |
    tool_result() |
    mcp_tool_use() |
    mcp_tool_result() |
    server_use_tool() |
    web_search_tool_result() |
    code_execution_tool_result() |
    container_upload()

  @type text_content() :: %{
    :type => String.t(),
    :text => String.t(),
    optional(:cache_control) => map(),  # todo expand
    optional(:citations) => list(map()) # todo expand
  }

  @type image_content() :: %{
    :type => String.t(),
    :source => map(),                   # todo expand
    optional(:cache_control) => map(),  # todo expand
  }

  @type document_content() :: %{
    :type => String.t(),
    :source => map(),                   # todo expand
    optional(:cache_control) => map(),  # todo expand
  }

  @type thinking() :: %{
    type: String.t(),
    thinking: String.t(),
    signature: String.t(),
  }

  @type redacted_thinking() :: %{
    type: String.t(),
    data: String.t(),
  }

  @type tool_use() :: %{
    :type => String.t(),
    :id => String.t(),
    :name => String.t(),
    :input => String.t(),
    optional(:cache_control) => map(),  # todo expand
  }

  @type tool_result() :: %{
    :type => String.t(),
    :tool_use_id => String.t(),
    :content => String.t() | list(text_content() | image_content()),
    optional(:is_error) => boolean(),
    optional(:cache_control) => map(),  # todo expand
  }

  @type mcp_tool_use() :: %{
    :type => String.t(),
    :id => String.t(),
    :name => String.t(),
    :server_name => String.t(),
    :input => map(),
    optional(:cache_control) => map(),  # todo expand
  }

  @type mcp_tool_result() :: %{
    :type => String.t(),
    :tool_use_id => String.t(),
    :content => String.t() | list(text_content()),
    optional(:is_error) => boolean(),
    optional(:cache_control) => map(),  # todo expand
  }

  @type server_use_tool() :: %{
    :type => String.t(),
    :id => String.t(),
    :name => String.t(),
    :input => map(),
    optional(:cache_control) => map(),  # todo expand
  }

  @type web_search_tool_result() :: %{
    :type => String.t(),
    :tool_use_id => String.t(),
    :content => list(map()) | map(),
    optional(:cache_control) => map(),  # todo expand
  }

  @type code_execution_tool_result() :: %{
    :type => String.t(),
    :tool_use_id => String.t(),
    :content => map(),
    optional(:cache_control) => map(),  # todo expand
  }

  @type container_upload() :: %{
    :type => String.t(),
    :file_id => String.t(),
    optional(:cache_control) => map(),  # todo expand
  }

  # Schemas

  defschema :message, %{
    role: {:required, {:enum, ["user", "assistant"]}},
    content: {:required, {:either, {
      {:string, {:transform, &string_to_text_content/1}},
      {:list, get_schema(:content_block)}
    }}}
  }

  defschema :content_block, {:oneof, [
    get_schema(:text_content),
    get_schema(:image_content),
    get_schema(:document_content),
    get_schema(:thinking),
    get_schema(:redacted_thinking),
    get_schema(:tool_use),
    get_schema(:tool_result),
    get_schema(:mcp_tool_use),
    get_schema(:mcp_tool_result),
    get_schema(:server_tool_use),
    get_schema(:web_search_tool_result),
    get_schema(:code_execution_tool_result),
    get_schema(:container_upload)
  ]}

  # Content block schemas

  defschema :text_content, %{
    type: {:required, {:literal, "text"}},
    text: {:required, :string},
    cache_control: {:either, {get_schema(:_cache_control), nil}},
    citations: {:list, get_schema(:_citation)},
  }

  defschema :image_content, %{
    type: {:required, {:literal, "image"}},
    source: {:required, {:oneof, [
      get_schema(:base64_source),
      get_schema(:url_source),
      get_schema(:file_source)
    ]}},
    cache_control: {:either, {get_schema(:_cache_control), nil}},
  }

  defschema :document_content, %{
    type: {:required, {:literal, "document"}},
    source: {:required, {:oneof, [
      get_schema(:base64_source),
      get_schema(:text_source),
      get_schema(:content_source),
      get_schema(:url_source),
      get_schema(:file_source)
    ]}},
    title: {:string, {:max, 500}},
    context: :string,
    cache_control: {:either, {get_schema(:_cache_control), nil}},
    citations: {:list, get_schema(:_citation)},
  }

  defschema :thinking, %{
    type: {:required, {:literal, "thinking"}},
    thinking: {:required, :string},
    signature: {:required, :string},
  }

  defschema :redacted_thinking, %{
    type: {:required, {:literal, "redacted_thinking"}},
    data: {:required, :string},
  }

  defschema :tool_use, %{
    type: {:required, {:literal, "tool_use"}},
    id: {:required, :string},
    name: {:required, {:string, {:max, 200}}},
    input: :map,
    cache_control: {:either, {get_schema(:_cache_control), nil}},
  }

  defschema :tool_result, %{
    type: {:required, {:literal, "tool_result"}},
    tool_use_id: {:required, :string},
    content: {:required, {:either, {
      {:string, {:transform, &string_to_text_content/1}},
      {:list, {:oneof, [
        get_schema(:text_content),
        get_schema(:image_content),
      ]}}
    }}},
    is_error: :boolean,
    cache_control: {:either, {get_schema(:_cache_control), nil}},
  }

  defschema :mcp_tool_use, %{
    type: {:required, {:literal, "mcp_tool_use"}},
    id: {:required, :string},
    name: {:required, :string},
    server_name: {:required, :string},
    input: :map,
    cache_control: {:either, {get_schema(:_cache_control), nil}},
  }

  defschema :mcp_tool_result, %{
    type: {:required, {:literal, "mcp_tool_result"}},
    tool_use_id: {:required, :string},
    content: {:required, {:either, {
      {:string, {:transform, &string_to_text_content/1}},
      {:list, {:oneof, [
        get_schema(:text_content),
      ]}}
    }}},
    is_error: :boolean,
    cache_control: {:either, {get_schema(:_cache_control), nil}},
  }

  defschema :server_tool_use, %{
    type: {:required, {:literal, "server_tool_use"}},
    id: {:required, :string},
    name: {:required, {:enum, ["web_search", "code_execution"]}},
    input: :map,
    cache_control: {:either, {get_schema(:_cache_control), nil}},
  }

  defschema :web_search_tool_result, %{
    type: {:required, {:literal, "web_search_tool_result"}},
    tool_use_id: {:required, :string},
    content: {:required, {:either, {
      {:list, get_schema(:web_search_tool_result_content)},
      get_schema(:web_search_tool_result_error)
    }}},
    cache_control: {:either, {get_schema(:_cache_control), nil}},
  }

  defschema :code_execution_tool_result, %{
    type: {:required, {:literal, "code_execution_tool_result"}},
    tool_use_id: {:required, :string},
    content: {:required, {:either, {
      get_schema(:code_execution_tool_result_content),
      get_schema(:code_execution_tool_result_error)
    }}},
    cache_control: {:either, {get_schema(:_cache_control), nil}},
  }

  defschema :container_upload, %{
    type: {:required, {:literal, "container_upload"}},
    file_id: {:required, :string},
    cache_control: {:either, {get_schema(:_cache_control), nil}},
  }

  # Source schemas

  defschema :base64_source, %{
    type: {:required, {:literal, "base64"}},
    media_type: {:required, {:enum, [
      "image/jpeg",
      "image/png",
      "image/gif",
      "image/webp",
      "application/pdf"
    ]}},
    data: {:required, :string}
  }

  defschema :text_source, %{
    type: {:required, {:literal, "text"}},
    media_type: {:required, {:literal, "text/plain"}},
    data: {:required, :string}
  }

  defschema :content_source, %{
    type: {:required, {:literal, "content"}},
    content: {:required, {:either, {
      {:string, {:transform, &string_to_text_content/1}},
      {:list, {:oneof, [
        get_schema(:text_content),
        get_schema(:image_content)
      ]}}
    }}}
  }

  defschema :url_source, %{
    type: {:required, {:literal, "url"}},
    url: {:required, :string}
  }

  defschema :file_source, %{
    type: {:required, {:literal, "file"}},
    file_id: {:required, :string}
  }

  # Server tool results

  defschema :web_search_tool_result_content, %{
    type: {:required, {:literal, "web_search_result"}},
    title: {:required, :string},
    encrypted_content: {:required, :string},
    url: {:required, :string},
    page_age: :string
  }

  defschema :web_search_tool_result_error, %{
    type: {:required, {:literal, "web_search_tool_result_error"}},
    error_code: {:required, :string}
  }

  defschema :code_execution_tool_result_content, %{
    type: {:required, {:literal, "code_execution_result"}},
    content: {:required, {:list, %{
      type: {:required, {:literal, "code_execution_output"}},
      file_id: {:required, :string}
    }}},
    return_code: {:required, :integer},
    stderr: :string,
    stdout: :string
  }

  defschema :code_execution_tool_result_error, %{
    type: {:required, {:literal, "code_execution_tool_result_error"}},
    error_code: {:required, :string}
  }

  # todo - define in message request?

  defschema :_cache_control, %{
    type: {:required, {:literal, "ephemeral"}},
    ttl: {:enum, ["5m", "1h"]}
  }

  defschema :_citation, %{
    # todo
  }

  # Functions


  @spec new(params :: Enumerable.t()) :: {:ok, t()} | {:error, term()}
  def new(params) when is_map(params) or is_list(params) do
    with {:ok, params} <- message(params) do
      {:ok, struct(__MODULE__, params)}
    end
  end

  @spec new(
    role :: :user | :assistant | String.t(),
    content :: String.t() | list(content_block())
  ) :: {:ok, t()} | {:error, term()}
  def new(role, content) when role in [:user, :assistant] do
    new(Atom.to_string(role), content)
  end

  def new(role, content) when is_binary(role) do
    new(role: role, content: content)
  end

  @spec new!(params :: Enumerable.t()) :: t()
  def new!(params) when is_map(params) or is_list(params) do
    struct!(__MODULE__, message!(params))
  end

  @spec new(
    role :: :user | :assistant | String.t(),
    content :: String.t() | list(content_block())
  ) :: t()
  def new!(role, content) when role in [:user, :assistant] do
    new!(Atom.to_string(role), content)
  end

  def new!(role, content) when is_binary(role) do
    new!(role: role, content: content)
  end

  # Helpers

  @spec string_to_text_content(String.t()) :: [text_content()]
  defp string_to_text_content(text) when is_binary(text) do
    [%{type: "text", text: text}]
  end

end
