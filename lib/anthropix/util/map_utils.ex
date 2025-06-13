defmodule Anthropix.Util.MapUtils do

  @doc """
  Recursively walks a map and converts string keys to atoms, but only if the
  atom already exists. Removes key-value pairs where the string key doesn't
  correspond to an existing atom.
  """
  def safe_atomize_keys(data) when is_map(data) do
    Enum.reduce(data, %{}, fn {key, value}, acc ->
      case convert_key(key) do
        {:error, :unsafe} -> acc
        new_key ->
          Map.put(acc, new_key, safe_atomize_keys(value))
      end
    end)
  end

  def safe_atomize_keys(data) when is_list(data) do
    Enum.map(data, &safe_atomize_keys/1)
  end

  def safe_atomize_keys(data), do: data

  # Helper function to convert keys
  defp convert_key(key) when is_binary(key) do
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> {:error, :unsafe}
    end
  end

  defp convert_key(key), do: safe_atomize_keys(key)

end
