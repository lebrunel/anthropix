defmodule Anthropix.FunctionCall do
  @moduledoc """
  The `Anthropix.FunctionCall` module is used to capture function calls from Claud's
  responses and, match the function call to an existing `t:Anthropix.Tool.t/0`,
  and then invoke the function.

  Usually, function calling is all handled automatically by the
  `Anthropix.Agent` module.
  """
  alias Anthropix.Tool

  @behaviour Saxy.Handler

  defstruct name: nil, args: %{}, result: nil

  @typedoc "Function Call struct"
  @type t() :: %__MODULE__{
    name: String.t(),
    args: %{optional(String.t()) => String.t()},
    result: any()
  }

  @xml_regex ~r/(<function_calls>.+?<\/function_calls>)/s

  @doc """
  Extracts function calls from the given text. Specifically, it looks for a
  `<function_calls>` XML snippet and parses any function calls into a list of
  `t:t/0` structs.
  """
  @spec extract!(String.t()) :: list(t())
  def extract!(text) when is_binary(text) do
    with [_match, xml] <- Regex.run(@xml_regex, text <> "</function_calls>"),
         {:ok, result} <- Saxy.parse_string(xml, __MODULE__, nil)
    do
      result
    else
      {:error, error} -> raise error
      _ -> []
    end
  end

  @doc """
  Invokes the given function using the matched tool. The arguments from the
  `t:t/0` struct are passed to the function, and the result is set on the
  FunctionCall struct.
  """
  @spec invoke(t(), Tool.t()) :: t()
  def invoke(%__MODULE__{} = function, %Tool{} = tool) do
    args = Enum.map(tool.params, & Map.fetch!(function.args, &1.name))
    result = case tool.function do
      fun when is_function(fun) -> apply(fun, args)
      {mod, fun, extra_args} -> apply(mod, fun, args ++ extra_args)
    end
    Map.put(function, :result, result)
  end

  @doc """
  Iterates over the given list of `t:t/0` structs, finding a matching
  `t:Tool.t/0` for each, and calling `invoke/2`. Returns a list of function
  calls with results or an exception of any function raises.
  """
  @spec invoke_all(list(t()), list(Tool.t())) :: list(t()) | Exception.t()
  def invoke_all(functions, tools) when is_list(functions) and is_list(tools) do
    Enum.map(functions, fn function ->
      invoke(function, Enum.find(tools, & &1.name == function.name))
    end)
  rescue
    err -> err
  end

  # Saxy callbacks

  @impl true
  def handle_event(:start_document, _prolog, _state) do
    {:ok, {[], []}}
  end

  def handle_event(:end_document, _data, {_stack, result}) do
    {:ok, Enum.reverse(result)}
  end

  def handle_event(:start_element, {name, _}, {stack, result}) do
    result = case name do
      "invoke" -> [struct(__MODULE__) | result]
      _ -> result
    end
    {:ok, {[name | stack], result}}
  end

  def handle_event(:end_element, _name, {[_ | stack], result}) do
    {:ok, {stack, result}}
  end

  def handle_event(:characters, val, {stack, [call | result]}) do
    call = case stack do
      ["tool_name", "invoke" | _] ->
        put_in(call.name, val)
      [key, "parameters", "invoke" | _] ->
        update_in(call.args, & Map.put(&1, key, val))
      _ ->
        call
    end
    {:ok, {stack, [call | result]}}
  end

  def handle_event(:characters, _val, state), do: {:ok, state}

end
