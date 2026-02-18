defmodule FProcess.FileDiscovery do
  @moduledoc """
  Handles file discovery, classification, and normalization.

  This module is the "input adapter" of the system. It takes any type
  of input (file, files, directory) and converts it into a normalized
  list of {type, path} tuples that the rest of the system can process.

  Key features:
  - Recursive directory scanning
  - File type classification by extension
  - Robust error handling
  - Consistent output format
  """

  @supported_extensions %{
    ".csv" => :csv,
    ".json" => :json,
    ".log" => :log,
    ".xml" => :xml
  }

  @type file_type :: :csv | :json | :log | :xml
  @type classified_file :: {file_type(), String.t()}

  @doc """
  Normalize any input into a list of {type, path} tuples.

  This is the main entry point for file discovery.

  ## Parameters

  - `input`: Can be:
    - A string path to a file
    - A string path to a directory (will be scanned recursively)
    - A list of file paths

  ## Returns

  - `{:ok, list}` where list is `[{:csv, "path"}, {:json, "path"}, ...]`
  - `{:error, reason}` if input is invalid or no files found

  ## Examples

      # Single file
      iex> normalize("data/valid/ventas_enero.csv")
      {:ok, [{:csv, "data/valid/ventas_enero.csv"}]}

      # Multiple files
      iex> normalize(["file1.csv", "file2.json"])
      {:ok, [{:csv, "file1.csv"}, {:json, "file2.json"}]}

      # Directory (recursive)
      iex> normalize("data")
      {:ok, [{:csv, "data/error/ventas_corrupto.csv"}, ...]}
  """
  @spec normalize(String.t() | list(String.t())) ::
    {:ok, map()} | {:error, String.t()}
  def normalize(input) when is_binary(input) do
    cond do
      File.dir?(input) ->
        normalize_directory(input)

      File.regular?(input) ->
        normalize_single_file(input)

      true ->
        {:error, "Path does not exist or is not accessible: #{input}"}
    end
  end

  def normalize(input) when is_list(input) and length(input) > 0 do
    normalize_file_list(input)
  end

  def normalize([]) do
    {:error, "Empty file list provided"}
  end

  def normalize(_input) do
    {:error, "Invalid input type. Expected string path or list of paths"}
  end

  @doc """
  Classify a file by its extension.

  ## Examples

      iex> classify_file("test.csv")
      {:ok, :csv}

      iex> classify_file("test.txt")
      {:error, :unsupported_format}
  """
  @spec classify_file(String.t()) :: {:ok, file_type()} | {:error, :unsupported_format}
  def classify_file(path) do
    extension = Path.extname(path) |> String.downcase()

    case Map.get(@supported_extensions, extension) do
      nil -> {:error, :unsupported_format}
      type -> {:ok, type}
    end
  end

  @doc """
  Check if a file has a supported extension.
  """
  @spec supported_file?(String.t()) :: boolean()
  def supported_file?(path) do
    extension = Path.extname(path) |> String.downcase()
    Map.has_key?(@supported_extensions, extension)
  end

  @doc """
  Get map of all supported extensions.
  """
  @spec supported_extensions() :: map()
  def supported_extensions, do: @supported_extensions

  @doc """
  Get list of supported extension strings.
  """
  @spec supported_extension_list() :: list(String.t())
  def supported_extension_list, do: Map.keys(@supported_extensions)

  @doc """
  Recursively find all supported files in a directory tree.

  This function will traverse subdirectories and collect all files
  with supported extensions.

  ## Examples

      iex> find_all_files("data")
      ["data/valid/file1.csv", "data/error/file2.json", ...]
  """
  @spec find_all_files(String.t()) :: list(String.t())
  def find_all_files(directory) do
    if File.dir?(directory) do
      safe_scan_directory(directory)
    else
      []
    end
  end

  # Private functions

  defp normalize_directory(directory) do
    case safe_list_directory(directory) do
      {:ok, _entries} ->
        files = find_all_files(directory)

        classified_files =
          files
          |> Enum.map(&classify_and_tuple/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.sort_by(fn {type, path} -> {type, path} end)

        case classified_files do
          [] -> {:error, "No supported files found in directory: #{directory}"}
          files -> {:ok, %{files: files, skipped: []}}
        end

      {:error, reason} ->
        {:error, "Failed to read directory '#{directory}': #{inspect(reason)}"}
    end
  end

  defp normalize_single_file(file_path) do
    if File.regular?(file_path) do
      case classify_file(file_path) do
        {:ok, type} ->
          {:ok, %{files: [{type, file_path}], skipped: []}}

        {:error, :unsupported_format} ->
          ext = Path.extname(file_path)
          {:error, {file_path, "Unsupported file format '#{ext}'. Supported: #{format_supported_extensions()}"}}
      end
    else
      {:error, {file_path, "File does not exist or is not a regular file"}}
    end
  end

  defp normalize_file_list(file_list) do
    {valid, invalid} =
      file_list
      |> Enum.map(&normalize_single_file/1)
      |> Enum.split_with(fn
        {:ok, _} -> true
        {:error, _} -> false
      end)

    case {valid, invalid} do
      {[], _} ->
        {:error, "No valid files found in the provided list"}

      {valid_files, []} ->
        result =
          valid_files
          |> Enum.flat_map(fn {:ok, data} -> data.files end)
          |> Enum.sort_by(fn {type, path} -> {type, path} end)

        {:ok, %{files: result, skipped: []}}

      {valid_files, invalid_files} ->
        # Some valid, some invalid - proceed with valid ones and collect invalid messages
        result =
          valid_files
          |> Enum.flat_map(fn {:ok, data} -> data.files end)

        skipped =
          invalid_files
          |> Enum.map(fn
            {:error, {path, reason}} -> {path, reason}
            {:error, reason} when is_binary(reason) -> {nil, reason}
          end)

        {:ok, %{files: result, skipped: skipped}}
    end
  end

  defp safe_scan_directory(directory) do
    try do
      directory
      |> File.ls!()
      |> Enum.flat_map(fn entry ->
        full_path = Path.join(directory, entry)

        cond do
          File.dir?(full_path) ->
            # Recursively scan subdirectory
            safe_scan_directory(full_path)

          File.regular?(full_path) and supported_file?(full_path) ->
            # Include this file
            [full_path]

          true ->
            # Skip unsupported files and other types (symlinks, etc.)
            []
        end
      end)
    rescue
      _e in File.Error ->
        # Return empty and let caller handle skipped items
        []
    end
  end

  defp safe_list_directory(directory) do
    try do
      entries = File.ls!(directory)
      {:ok, entries}
    rescue
      e in File.Error ->
        {:error, Exception.message(e)}
    end
  end

  defp classify_and_tuple(path) do
    case classify_file(path) do
      {:ok, type} -> {type, path}
      {:error, _} -> nil
    end
  end

  defp format_supported_extensions do
    @supported_extensions
    |> Map.keys()
    |> Enum.join(", ")
  end
end
