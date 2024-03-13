defmodule Anthropix.XML do
  @moduledoc """
  Support module for encoding XML data into prompts. Mainly used to support
  function calling.
  """
  alias Anthropix.{FunctionCall, Tool}
  import Saxy.XML, only: [element: 3]

  @allowed_roots [:tools, :function_results]

  @doc """
  Encodes the given data into the specified message type.

  Supports encoding a list of `t:Anthropix.Tool.t/0` structs into a `:tools`
  message, or a list of `t:Anthropix.FunctionCall.t/0` structs into a
  `:function_results` message.

  ## Examples

  ```elixir
  iex> Anthropix.XML.encode(:tools, [
  ...>   %Anthropix.Tool{name: "a", description: "aaa", params: [
  ...>     %{name: "b", description: "bbb", type: "string"}
  ...>   ]}
  ...> ])
  "<tools><tool_description><tool_name>a</tool_name><description>aaa</description><parameters><parameter><name>b</name><description>bbb</description><type>string</type></parameter></parameters></tool_description></tools>"

  iex> Anthropix.XML.encode(:function_results, [
  ...>   %Anthropix.FunctionCall{name: "a", result: "aaa"}
  ...> ])
  "<function_results><result><tool_name>a</tool_name><stdout>aaa</stdout></result></function_results>"
  ```
  """
  @spec encode(atom(), term()) :: String.t()
  def encode(type, data) when type in @allowed_roots,
    do: el(type, data) |> Saxy.encode!()


  # Builds a SAX element of the specified type using the given data.
  @spec el(atom(), data :: term()) :: Saxy.XML.element()
  defp el(:tools, tools) when is_list(tools),
    do: element(:tools, [], Enum.map(tools, & el(:tool, &1)))

  defp el(:tool, %Tool{} = tool) do
    element(:tool_description, [], [
      element(:tool_name, [], tool.name),
      element(:description, [], tool.description),
      element(:parameters, [], Enum.map(tool.params, & el(:param, &1)))
    ])
  end

  defp el(:param, %{name: name, description: description, type: type}) do
    element(:parameter, [], [
      element(:name, [], name),
      element(:description, [], description),
      element(:type, [], type),
    ])
  end

  defp el(:function_results, functions) when is_list(functions) do
    element(:function_results, [], Enum.map(functions, & el(:result, &1)))
  end

  defp el(:function_results, error) when is_exception(error) do
    element(:function_results, [], [
      element(:error, [], inspect(error.__struct__))
    ])
  end

  defp el(:result, %FunctionCall{} = function) do
    element(:result, [], [
      element(:tool_name, [], function.name),
      element(:stdout, [], function.result)
    ])
  end

end
