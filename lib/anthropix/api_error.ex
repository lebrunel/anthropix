defmodule Anthropix.APIError do
  @moduledoc false
  defexception [:status, :type, :message]

  @impl true
  def exception(%{status: status, body: %{"error" => %{"type" => type, "message" => message}}}) do
    struct(__MODULE__, [
      status: status,
      type: type,
      message: message,
      ])
  end

  def exception(%{status: status, body: body}) when is_binary(body) do
    message = case {status, body} do
      {529, ""} -> "Overloaded"
      {_, ""} -> "Empty response"
      {_, message} -> message
    end
    struct(__MODULE__, [
      status: status,
      message: message,
    ])
  end
end
