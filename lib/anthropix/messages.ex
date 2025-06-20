defmodule Anthropix.Messages do
  alias Anthropix.Messages
  import Anthropix.Util.ReqUtils, only: [handle_response: 2]

  def generate() do

  end

  def stream() do

  end

  @spec count_tokens(client :: Anthropix.t(), params :: Messages.Request.request())
    :: {:ok, %{input_tokens: integer()}}
    | {:error, any()}
  def count_tokens(%Anthropix{} = client, params) do
    with {:ok, request} <- Messages.Request.token_count_request(params) do
      client.req
      |> Req.post(url: "/messages/count_tokens", json: request)
      |> handle_response(& {:ok, Recase.Enumerable.atomize_keys(&1)})
    end
  end

end
