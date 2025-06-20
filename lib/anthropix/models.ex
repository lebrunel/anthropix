defmodule Anthropix.Models do
  import Peri
  import Anthropix.Util.ReqUtils, only: [handle_response: 2]

  @type model() :: %{
    type: String.t(),
    id: String.t(),
    display_name: String.t(),
    created_at: DateTime.t()
  }

  @type model_list() :: %{
    data: list(model()),
    first_id: String.t() | nil,
    last_id: String.t() | nil,
    has_more: boolean()
  }

  defschema :model, %{
    type: {:literal, "model"},
    id: :string,
    display_name: :string,
    created_at: {:string, {:transform, &to_datetime/1}}
  }

  defschema :list_params, %{
    limit: {:integer, {:range, {1, 1000}}},
    before_id: :string,
    after_id: :string,
  }

  defschema :list_response, %{
    data: {:list, get_schema(:model)},
    first_id: {:either, {:string, nil}},
    last_id: {:either, {:string, nil}},
    has_more: :boolean,
  }

  @spec list(client :: Anthropix.client(), params :: Enumerable.t()) ::
    {:ok, model_list()} |
    {:error, term()}
  def list(%Anthropix{} = client, params \\ []) do
    with {:ok, params} <- list_params(params) do
      client.req
      |> Req.get(url: "/models", params: params)
      |> handle_response(&list_response/1)
    end
  end

  @spec show(client :: Anthropix.client(), model_id :: String.t()) ::
    {:ok, model()} |
    {:error, term()}
  def show(%Anthropix{} = client, model_id) when is_binary(model_id) do
    client.req
    |> Req.get(url: "/models/#{model_id}")
    |> handle_response(&model/1)
  end

  # Helpers

  defp to_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      {:error, reason} -> raise reason
    end
  end
end
