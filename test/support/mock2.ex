defmodule Anthropix.Mock2 do
  import Plug.Conn

  @spec respond(binary, Keyword.t()) :: (Plug.Conn.t() -> Plug.Conn.t())
  def respond(filename, opts \\ []) when is_binary(filename) do
    data = File.read!("test/mocks/#{filename}")
    content_type = Keyword.get(opts, :content_type, "application/json")
    headers = Keyword.get(opts, :headers, [])

    fn conn ->
      headers
      |> Enum.reduce(conn, &headers_reducer/2)
      |> put_resp_content_type(content_type)
      |> send_resp(200, data)
    end
  end

  @spec stream(binary, Keyword.t()) :: (Plug.Conn.t() -> Plug.Conn.t())
  def stream(filename, opts \\ []) when is_binary(filename) do
    messages =
      File.read!("test/mocks/#{filename}")
      |> String.split("\n")
      |> Enum.filter(& byte_size(&1) > 0)

    headers = Keyword.get(opts, :headers, [])

    fn conn ->
      conn =
        headers
        |> Enum.reduce(conn, &headers_reducer/2)
        |> send_chunked(200)

      Enum.reduce(messages, conn, fn message, conn ->
        {:ok, conn} = chunk(conn, to_sse_event(message))
        conn
      end)
    end
  end

  defp headers_reducer({key, value}, conn) do
    put_req_header(conn, key, value)
  end

  defp to_sse_event(data) do
    %{"type" => event} = Jason.decode!(data)

    """
    event: #{event}
    data: #{data}\n\n
    """
  end
end
