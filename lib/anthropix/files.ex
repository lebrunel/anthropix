defmodule Anthropix.Files do
  @moduledoc """
  TODO

  NB: beta - files-api-2025-04-14
  """

  import Peri
  import Anthropix.Util.ReqUtils, only: [handle_response: 1, handle_response: 2]

  @type request() :: %{
    :filename => String.t(),
    optional(:mime_type) => String.t(),
    optional(:data) => binary() | File.Stream.t()
  }

  @type response() :: %{
    type: String.t(),
    id: String.t(),
    filename: String.t(),
    mime_type: String.t(),
    size_bytes: integer(),
    downloadable: boolean(),
    created_at: String.t()
  }

  defschema :request, %{
    filename: {:required, :string},
    mime_type: :string,
    data: :string,
  }

  defschema :response, %{
    type: {:required, {:literal, "file"}},
    id: {:required, :string},
    filename: {:required, :string},
    mime_type: :string,
    size_bytes: :integer,
    downloadable: :boolean,
    created_at: {:string, {:transform, &to_datetime/1}},
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

  @spec create(
    client :: Anthropix.client(),
    file_path_or_params :: String.t() | request()
  ) :: {:ok, response()} | {:error, term()}
  def create(%Anthropix{} = client, filepath) when is_binary(filepath),
    do: create(client, filename: filepath)

  def create(%Anthropix{} = client, params) when is_map(params) or is_list(params) do
    with {:ok, params} <- request(params),
         {:ok, file} <- build_file(params)
    do
      client.req
      |> Req.post(url: "/files", form_multipart: [file: file])
      |> handle_response(&response/1)
    end
  end

  @spec list(client :: Anthropix.client(), params :: Enumerable.t()) ::
    {:ok, response()} |
    {:error, term()}
  def list(%Anthropix{} = client, params \\ []) do
    with {:ok, params} <- list_params(params) do
      client.req
      |> Req.get(url: "/files", params: params)
      |> handle_response(&list_response/1)
    end
  end

  @spec show(client :: Anthropix.client(), file_id :: String.t()) ::
    {:ok, response()} |
    {:error, term()}
  def show(%Anthropix{} = client, file_id) when is_binary(file_id) do
    client.req
    |> Req.get(url: "/files/#{file_id}")
    |> handle_response(&response/1)
  end

  @spec download(client :: Anthropix.client(), file_id :: String.t()) ::
    {:ok, binary()} |
    {:error, term()}
  def download(%Anthropix{} = client, file_id) when is_binary(file_id) do
    client.req
    |> Req.get(url: "/files/#{file_id}/content")
    |> handle_response()
  end

  @spec delete(client :: Anthropix.client(), file_id :: String.t()) ::
    {:ok, %{id: String.t(), type: String.t()}} |
    {:error, term()}
  def delete(%Anthropix{} = client, file_id) when is_binary(file_id) do
    client.req
    |> Req.delete(url: "/files/#{file_id}")
    |> handle_response(& {:ok, Recase.Enumerable.atomize_keys(&1)})
  end

  # Helpers

  @spec build_file(params :: request()) :: {:ok, {binary() | File.Stream.t(), keyword()}} | {:error, term()}
  defp build_file(%{data: data} = params) do
    %{filename: filename, mime_type: content_type} =
      params
      |> Map.update!(:filename, &Path.basename/1)
      |> Map.put_new_lazy(:mime_type, fn -> MIME.from_path(params.filename) end)

    {:ok, {data, [filename: filename, content_type: content_type]}}
  end

  defp build_file(%{filename: filename} = params) do
    case File.stat(filename) do
      {:ok, %File.Stat{type: :regular}} ->
        params
        |> Map.put(:data, File.stream!(filename, [], 2048))
        |> build_file()

      {:ok, %File.Stat{type: type}} ->
        {:error, "Path is not a regular file (it's a #{type})"}

      {:error, reason} ->
        {:error, "Cannot read file: #{:file.format_error(reason)}"}
    end
  end

  defp to_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      {:error, reason} -> raise reason
    end
  end

end
