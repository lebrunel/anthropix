defmodule Anthropix.Util.ReqUtils do
  import Anthropix.Util.MapUtils, only: [safe_atomize_keys: 1]
  alias Anthropix.APIError

  @type transformer() :: (map() -> {:ok, map()} | {:error, term()})

  @doc """
  TODO
  """
  @spec handle_response({:ok, Req.Response.t()} | {:error, term()}, transformer()) :: {:ok, any()} | {:error, term()}
  def handle_response(req_result, transform \\ fn res -> {:ok, res.body} end)

  def handle_response({:ok, %{status: status, body: body} = raw}, transform) when status in 200..299 do
    with {:ok, res} <- transform.(safe_atomize_keys(body)) do
      res = case res do
        res when is_map(res) -> Map.put(res, :raw, raw)
        res -> res
      end
      {:ok, res}
    end
  end

  def handle_response({:ok, res}, _transform), do: {:error, APIError.exception(res)}
  def handle_response({:error, error}, _transform), do: {:error, error}

end
