defmodule Anthropix.Tools.WebSearch do
  use Anthropix.Tool, type: :server
  import Peri
  alias Anthropix.Messages

  @versions ["web_search_20250305"]
  name "web_search"

  defschema :config, %{
    type: {{:enum, @versions}, {:default, "web_search_20250305"}},
    allowed_domains: {:list, :string},
    blocked_domains: {:list, :string},
    max_uses: {:integer, {:gt, 0}},
    user_location: {:either, {%{
      type: {:required, {:literal, "approximate"}},
      city: {:string, {:max, 255}},
      country: {:string, {:regex, ~r/^[A-Z]{2}$/}},
      region: {:string, {:max, 255}},
      timezone: {:string, {:max, 255}}
    }, nil}},
    cache_control: {:either, {Messages.Request.get_schema(:cache_control), nil}},
  }

  @impl true
  def init(params), do: config(params)

end
