defmodule Anthropix.APIError do
  @moduledoc false
  defexception [:status, :type, :message]

  @impl true
  def exception(%Req.Response{status: status, body: body}) when is_map(body) do
    %{exception(body) | status: status}
  end

  def exception(%Req.Response{status: status, body: body}) when is_binary(body) do
    message = case {status, body} do
      {529, ""} -> "Overloaded"
      {_, ""} -> "Empty response"
      {_, message} -> message
    end
    struct(__MODULE__, status: status, message: message)
  end

  def exception(%{"error" => %{"type" => type, "message" => message}}) do
    struct(__MODULE__, type: type, message: message)
  end

end
