defmodule Anthropix.Batches do
  import Peri
  import Anthropix.Util.MapUtils, only: [safe_atomize_keys: 1]
  alias Anthropix.StreamingResponse
  alias Anthropix.{APIError, Messages}

  @type request() :: list(%{
    custom_id: String.t(),
    params: Messages.Request.request()
  }) | %{
    requests: %{
      custom_id: String.t(),
      params: Messages.Request.request()
    }
  }

  @type response() :: %{
    type: String.t(),
    id: String.t(),
    processing_status: String.t(),
    results_url: String.t() | nil,
    request_counts: %{
      canceled: integer(),
      errored: integer(),
      expired: integer(),
      processing: integer(),
      succeeded: integer()
    },
    created_at: String.t(),
    expires_at: String.t(),
    ended_at: String.t() | nil,
    cancel_initiated_at: String.t() | nil,
    archived_at: String.t() | nil,
  }

  @type result() :: %{
    custom_id: String.t(),
    result: response() | map()
  }

  defschema :request, {:either, {
    {{:list, get_schema(:request_params)}, {:transform, & %{requests: &1}}},
    %{
      requests: {:list, get_schema(:request_params)}
    }
  }}

  defschema :request_params, %{
    custom_id: {:required, :string},
    params: Messages.Request.get_schema(:request)
  }

  defschema :response, %{
    type: {:literal, "message_batch"},
    id: {:required, :string},
    processing_status: {:enum, ["in_progress", "canceling", "ended"]},
    results_url: {:either, {:string, nil}},
    request_counts: %{
      canceled: :integer,
      errored: :integer,
      expired: :integer,
      processing: :integer,
      succeeded: :integer
    },
    created_at: {:required, :string},
    expires_at: {:required, :string},
    ended_at: {:either, {:string, nil}},
    cancel_initiated_at: {:either, {:string, nil}},
    archived_at: {:either, {:string, nil}},
  }

  defschema :result, %{
    custom_id: {:required, :string},
    result: %{
      type: {:enum, ["succeeded", "errored", "cancelled", "expired"]},
      message: {:cond, & &1.result.type == "succeeded", Messages.Response.get_schema(:response), nil},
      error: {:cond, & &1.result.type != "succeeded", %{type: :string, message: :string}, nil},
    }
  }

  defschema :list_params, %{
    limit: {:integer, {:range, {1, 1000}}},
    before_id: :string,
    after_id: :string,
  }

  defschema :list_response, %{
    data: {:list, get_schema(:response)},
    first_id: {:either, {:string, nil}},
    last_id: {:either, {:string, nil}},
    has_more: :boolean,
  }

  @spec create(client :: Anthropix.client(), params :: request()) ::
    {:ok, response()} |
    {:error, term()}
  def create(%Anthropix{} = client, params) when is_map(params) or is_list(params) do
    with {:ok, params} <- request(params) do
      client.req
      |> Req.post(url: "/messages/batches", json: params)
      |> handle_response(&response/1)
    end
  end

  @spec results(client :: Anthropix.client(), batch_id_or_url :: String.t()) ::
    {:ok, list(result())} |
    {:error, term()}
  def results(%Anthropix{} = client, batch_id_or_url) when is_binary(batch_id_or_url) do
    client.req
    |> Req.get(url: results_url(batch_id_or_url))
    |> handle_response(&jsonl_to_results/1)
  end

  @spec stream_results(
    client :: Anthropix.client(),
    batch_id_or_url :: String.t()
  ) :: StreamingResponse.t()
  def stream_results(%Anthropix{} = client, batch_id_or_url) when is_binary(batch_id_or_url) do
    client.req
    |> Req.merge(url: results_url(batch_id_or_url))
    |> StreamingResponse.init(StreamingResponse.Batches)
  end

  @spec list(client :: Anthropix.client(), params :: Enumerable.t()) ::
    {:ok, response()} |
    {:error, term()}
  def list(%Anthropix{} = client, params \\ []) do
    with {:ok, params} <- list_params(params) do
      client.req
      |> Req.get(url: "/messages/batches", params: params)
      |> handle_response(&list_response/1)
    end
  end

  @spec show(client :: Anthropix.client(), batch_id :: String.t()) ::
    {:ok, response()} |
    {:error, term()}
  def show(%Anthropix{} = client, batch_id) when is_binary(batch_id) do
    client.req
    |> Req.get(url: "/messages/batches/#{batch_id}")
    |> handle_response(&response/1)
  end

  @spec cancel(client :: Anthropix.client(), batch_id :: String.t()) ::
    {:ok, response()} |
    {:error, term()}
  def cancel(%Anthropix{} = client, batch_id) when is_binary(batch_id) do
    client.req
    |> Req.post(url: "/messages/batches/#{batch_id}/cancel")
    |> handle_response(&response/1)
  end

  @spec delete(client :: Anthropix.client(), batch_id :: String.t()) ::
    {:ok, map()} |
    {:error, term()}
  def delete(%Anthropix{} = client, batch_id) when is_binary(batch_id) do
    client.req
    |> Req.delete(url: "/messages/batches/#{batch_id}")
    |> handle_response()
  end

  # Helpers

  @typep transformer() :: (map() -> {:ok, map()} | {:error, term()})

  @spec handle_response({:ok, Req.Response.t()} | {:error, term()}, transformer()) :: {:ok, response()} | {:error, term()}

  defp handle_response(req_result, transform \\ fn res -> {:ok, res} end)

  defp handle_response({:ok, %{status: status, body: body} = raw}, transform) when status in 200..299 do
    with {:ok, res} <- transform.(safe_atomize_keys(body)) do
      res = case res do
        res when is_map(res) -> Map.put(res, :raw, raw)
        res -> res
      end
      {:ok, res}
    end
  end

  defp handle_response({:ok, res}, _transform), do: {:error, APIError.exception(res)}
  defp handle_response({:error, error}, _transform), do: {:error, error}

  @spec jsonl_to_results(String.t()) :: {:ok, list(result())}
  defp jsonl_to_results(jsonl) when is_binary(jsonl) do
    results =
      jsonl
      |> String.split("\n")
      |> Enum.filter(& byte_size(&1) > 0)
      |> Enum.map(&Jason.decode!/1)
      |> Enum.map(&safe_atomize_keys/1)
      |> Enum.map(&result!/1)

    {:ok, results}
  end

  @spec results_url(String.t()) :: String.t()
  defp results_url(batch_id_or_url) when is_binary(batch_id_or_url) do
    case String.match?(batch_id_or_url, ~r/^https?:\/\//) do
      true -> batch_id_or_url
      false -> "/messages/batches/#{batch_id_or_url}/results"
    end
  end

end
