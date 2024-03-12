defmodule Anthropix.XML do
  alias Anthropix.FunctionCall
  alias Anthropix.Tool

  def encode(node, level \\ 0)
  def encode({name, _args, value}, level) when is_binary(value) do
    :binary.copy("  ", level) <> "<#{name}>#{value}</#{name}>"
  end
  def encode({name, _args, children}, level) when is_list(children) do
    indent = :binary.copy("  ", level)
    value = Enum.map(children, & encode(&1, level+1)) |> Enum.join("\n")
    "#{indent}<#{name}>\n#{value}\n#{indent}</#{name}>"
  end


  def function_results(calls) when is_list(calls) do
    el(:function_results, Enum.map(calls, &result/1))
  end

  def function_results(error) when is_exception(error) do
    el(:function_results, [
      el(:error, Exception.message(error))
    ])
  end

  def result(%FunctionCall{name: name, result: result}) do
    el(:result, [
      el(:tool_name, name),
      el(:stdout, result)
    ])
  end

  def tools(tools) when is_list(tools) do
    el(:tools, Enum.map(tools, &tool/1))
  end

  def tool(%Tool{name: name, description: description, params: params}) do
    el(:tool_description, [
      el(:tool_name, name),
      el(:description, description),
      el(:parameters, Enum.map(params, &param/1))
    ])
  end

  def param(%{name: name, description: description, type: type}) do
    el(:parameter, [
      el(:name, name),
      el(:description, description),
      el(:type, type),
    ])
  end

  @spec el(atom() | String.t(), list(tuple()) | String.t()) :: tuple()
  defp el(name, children), do: Saxy.XML.element(name, [], children)

  #@spec chars(String.t()) :: Saxy.XML.characters()
  #defp chars(text), do: Saxy.XML.characters(text)

end
