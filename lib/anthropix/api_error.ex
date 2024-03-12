defmodule Anthropix.APIError do
  @moduledoc false
  defexception [:type, :message]

  @impl true
  def exception(%{"error" => %{"type" => type, "message" => message}}) do
    struct(__MODULE__, [
      type: type,
      message: message,
    ])
  end

end
