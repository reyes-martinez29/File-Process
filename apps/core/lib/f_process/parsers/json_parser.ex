defmodule FProcess.Parsers.JSONParser do
  @moduledoc """
  Parser for JSON user and session data files.

  Expected structure:
  {
    "timestamp": "ISO-8601",
    "usuarios": [{id, nombre, email, activo, ultimo_acceso}, ...],
    "sesiones": [{usuario_id, inicio, duracion_segundos, paginas_visitadas, acciones}, ...]
  }

  Validates:
  - Required fields presence
  - Data types
  - Valid structure
  """

  alias FProcess.Structs.{User, Session}

  @doc """
  Parse a JSON file and return users and sessions data.

  Returns:
  - `{:ok, %{users: [...], sessions: [...], timestamp: ...}}` - Success
  - `{:error, reason}` - Failed to parse or validate
  """
  @spec parse(String.t()) ::
    {:ok, map()} |
    {:error, String.t()}
  def parse(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        parse_json_content(content)

      {:error, reason} ->
        {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  # ============================================================================
  # Private Functions - Parsing
  # ============================================================================

  defp parse_json_content(content) do
    case Jason.decode(content) do
      {:ok, data} ->
        validate_and_extract(data)

      {:error, %Jason.DecodeError{} = error} ->
        {:error, "Invalid JSON: #{Exception.message(error)}"}
    end
  end

  defp validate_and_extract(data) when is_map(data) do
    with {:ok, timestamp} <- extract_timestamp(data),
         {:ok, users} <- extract_users(data),
         {:ok, sessions} <- extract_sessions(data) do

      {:ok, %{
        timestamp: timestamp,
        users: users,
        sessions: sessions
      }}
    end
  end

  defp validate_and_extract(_data) do
    {:error, "Root element must be a JSON object"}
  end

  # ============================================================================
  # Private Functions - Field Extraction
  # ============================================================================

  defp extract_timestamp(data) do
    case Map.get(data, "timestamp") do
      nil ->
        {:ok, nil}  # Timestamp is optional

      timestamp when is_binary(timestamp) ->
        {:ok, timestamp}

      _ ->
        {:error, "timestamp must be a string"}
    end
  end

  defp extract_users(data) do
    case Map.get(data, "usuarios") do
      nil ->
        {:error, "Missing required field: usuarios"}

      usuarios when is_list(usuarios) ->
        parse_users(usuarios)

      _ ->
        {:error, "usuarios must be an array"}
    end
  end

  defp extract_sessions(data) do
    case Map.get(data, "sesiones") do
      nil ->
        {:error, "Missing required field: sesiones"}

      sesiones when is_list(sesiones) ->
        parse_sessions(sesiones)

      _ ->
        {:error, "sesiones must be an array"}
    end
  end

  # ============================================================================
  # Private Functions - Users Parsing
  # ============================================================================

  defp parse_users(usuarios_list) do
    {users, errors} =
      usuarios_list
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {user_data, index}, {users_acc, errors_acc} ->
        case parse_user(user_data, index) do
          {:ok, user} ->
            {[user | users_acc], errors_acc}

          {:error, reason} ->
            {users_acc, ["User at index #{index}: #{reason}" | errors_acc]}
        end
      end)

    if length(errors) > 0 do
      {:error, "User parsing errors: #{Enum.join(errors, "; ")}"}
    else
      {:ok, Enum.reverse(users)}
    end
  end

  defp parse_user(data, _index) when is_map(data) do
    with {:ok, id} <- get_required_integer(data, "id"),
         {:ok, nombre} <- get_required_string(data, "nombre"),
         {:ok, email} <- get_required_string(data, "email"),
         {:ok, activo} <- get_required_boolean(data, "activo") do

      ultimo_acceso = Map.get(data, "ultimo_acceso")

      user = %User{
        id: id,
        name: nombre,
        email: email,
        active: activo,
        last_access: ultimo_acceso
      }

      {:ok, user}
    end
  end

  defp parse_user(_data, _index) do
    {:error, "User must be an object"}
  end

  # ============================================================================
  # Private Functions - Sessions Parsing
  # ============================================================================

  defp parse_sessions(sesiones_list) do
    {sessions, errors} =
      sesiones_list
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {session_data, index}, {sessions_acc, errors_acc} ->
        case parse_session(session_data, index) do
          {:ok, session} ->
            {[session | sessions_acc], errors_acc}

          {:error, reason} ->
            {sessions_acc, ["Session at index #{index}: #{reason}" | errors_acc]}
        end
      end)

    if length(errors) > 0 do
      {:error, "Session parsing errors: #{Enum.join(errors, "; ")}"}
    else
      {:ok, Enum.reverse(sessions)}
    end
  end

  defp parse_session(data, _index) when is_map(data) do
    with {:ok, usuario_id} <- get_required_integer(data, "usuario_id") do

      inicio = Map.get(data, "inicio")
      duracion_segundos = Map.get(data, "duracion_segundos")
      paginas_visitadas = Map.get(data, "paginas_visitadas")
      acciones = Map.get(data, "acciones", [])

      # Validate acciones is a list
      acciones = if is_list(acciones), do: acciones, else: []

      session = %Session{
        user_id: usuario_id,
        start: inicio,
        duration_seconds: duracion_segundos,
        pages_visited: paginas_visitadas,
        actions: acciones
      }

      {:ok, session}
    end
  end

  defp parse_session(_data, _index) do
    {:error, "Session must be an object"}
  end

  # ============================================================================
  # Private Functions - Field Validators
  # ============================================================================

  defp get_required_integer(data, field) do
    case Map.get(data, field) do
      nil ->
        {:error, "Missing required field: #{field}"}

      value when is_integer(value) ->
        {:ok, value}

      value ->
        {:error, "Field #{field} must be an integer, got: #{inspect(value)}"}
    end
  end

  defp get_required_string(data, field) do
    case Map.get(data, field) do
      nil ->
        {:error, "Missing required field: #{field}"}

      value when is_binary(value) ->
        {:ok, value}

      value ->
        {:error, "Field #{field} must be a string, got: #{inspect(value)}"}
    end
  end

  defp get_required_boolean(data, field) do
    case Map.get(data, field) do
      nil ->
        {:error, "Missing required field: #{field}"}

      value when is_boolean(value) ->
        {:ok, value}

      value ->
        {:error, "Field #{field} must be a boolean, got: #{inspect(value)}"}
    end
  end
end
