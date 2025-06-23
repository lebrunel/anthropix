defmodule Anthropix.TestHelpers do

  @spec includes_error?(Peri.Error.t(), atom() | list(atom())) :: boolean()
  def includes_error?(%Peri.Error{key: key}, key) when is_atom(key), do: true
  def includes_error?(%Peri.Error{path: path}, path) when is_list(path), do: true

  def includes_error?(%Peri.Error{errors: errors}, key) when is_list(errors),
    do: Enum.any?(errors, &includes_error?(&1, key))

  def includes_error?(errors, key) when is_list(errors),
    do: Enum.any?(errors, &includes_error?(&1, key))

  def includes_error?(%Peri.Error{}, _key), do: false

end
