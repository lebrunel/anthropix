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
  def exception(%{status: status, body: ""}) do
    struct(__MODULE__, [
      status: status,
      message: "Empty response received",
      ])
  end

end
