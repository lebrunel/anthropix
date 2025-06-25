defmodule Anthropix.Messages do
  alias Anthropix.{APIError, Messages, StreamingResponse}
  import Anthropix.Util.ReqUtils, only: [handle_response: 2]

  @spec generate(client :: Anthropix.client(), params :: Messages.Request.request()) ::
    {:ok, Messages.Response.t()} |
    {:error, term()}
  def generate(%Anthropix{} = client, params) when is_map(params) or is_list(params) do
    with {:ok, request} <- Messages.Request.request(params) do
      case Req.post(client.req, url: "/messages", json: request) do
        {:ok, %{status: status} = res} when status in 200..299 ->
          Messages.Response.new(res)
        {:ok, res} ->
          {:error, APIError.exception(res)}
        {:error, error} ->
          {:error, error}
      end
    end
  end

  @spec stream(client :: Anthropix.client(), params :: Messages.Request.request()) ::
    {:ok, StreamingResponse.t()} |
    {:error, term()}
  def stream(%Anthropix{} = client, params) when is_map(params) or is_list(params) do
    with {:ok, request} <- Messages.Request.request(params) do
      streaming =
        client.req
        |> Req.merge(url: "/messages", json: Map.put(request, :stream, true))
        |> StreamingResponse.init(StreamingResponse.Messages)
      {:ok, streaming}
    end
  end

  @spec count_tokens(client :: Anthropix.client(), params :: Messages.Request.request()) ::
    {:ok, %{input_tokens: integer()}} |
    {:error, term()}
  def count_tokens(%Anthropix{} = client, params) do
    with {:ok, request} <- Messages.Request.token_count_request(params) do
      client.req
      |> Req.post(url: "/messages/count_tokens", json: request)
      |> handle_response(& {:ok, Recase.Enumerable.atomize_keys(&1)})
    end
  end

end
