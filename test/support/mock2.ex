defmodule Anthropix.Mock2 do
  import Plug.Conn
  alias Plug.Conn

  @spec respond(binary() | integer(), Keyword.t()) :: (Plug.Conn.t() -> Plug.Conn.t())
  def respond(filename_or_status, opts \\ [])

  def respond(filename, opts) when is_binary(filename) do
    data = File.read!("test/mocks/#{filename}")

    fn conn ->
      conn
      |> setup_conn(opts)
      |> send_resp(200, data)
    end
  end

  def respond(status, opts) when is_integer(status) do
    error = %{
      error: %{
        type: Conn.Status.reason_atom(status),
        message: Conn.Status.reason_phrase(status),
      }
    }

    fn conn ->
      conn
      |> setup_conn(opts)
      |> send_resp(status, Jason.encode!(error))
    end
  end

  @spec stream(binary, Keyword.t()) :: (Plug.Conn.t() -> Plug.Conn.t())
  def stream(filename, opts \\ []) when is_binary(filename) do
    messages =
      File.read!("test/mocks/#{filename}")
      |> String.split("\n")
      |> Enum.filter(& byte_size(&1) > 0)

    fn conn ->
      conn = conn
      |> setup_conn(opts)
      |> send_chunked(200)

      Enum.reduce(messages, conn, fn message, conn ->
        {:ok, conn} = chunk(conn, to_sse_event(message))
        conn
      end)
    end
  end

  defp setup_conn(conn, opts) do
    headers = Keyword.get(opts, :headers, [])

    conn = Enum.reduce(headers, conn, fn {key, value}, conn ->
      put_req_header(conn, key, value)
    end)

    case Keyword.get(opts, :content_type, "application/json") do
      nil -> conn
      type -> put_resp_content_type(conn, type)
    end
  end

  defp to_sse_event(data) do
    %{"type" => event} = Jason.decode!(data)

    """
    event: #{event}
    data: #{data}\n\n
    """
  end
end
