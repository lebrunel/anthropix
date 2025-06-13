defmodule Anthropix.Tools.CodeExecution do
  use Anthropix.Tool, type: :server
  import Peri
  alias Anthropix.Messages

  @versions ["code_execution_20250522"]
  name "code_execution"

  defschema :config, %{
    type: {{:enum, @versions}, {:default, "code_execution_20250522"}},
    cache_control: {:either, {Messages.Request.get_schema(:cache_control), nil}},
  }

  @impl true
  def init(opts), do: config(opts)

end
