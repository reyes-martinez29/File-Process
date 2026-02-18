defmodule FProcess.Structs do
  @moduledoc """
  Data structures used across the file processing system.

  These structs provide a clean contract for data flowing through
  the system, making the code more maintainable and type-safe.
  """

  defmodule Sale do
    @moduledoc """
    Represents a single sale record from CSV files.
    Used after parsing and validation.
    """
    @enforce_keys [:product, :category, :unit_price, :quantity]
    defstruct [
      :date,
      :product,
      :category,
      :unit_price,
      :quantity,
      :discount,
      :total
    ]

    @type t :: %__MODULE__{
            date: Date.t() | nil,
            product: String.t(),
            category: String.t(),
            unit_price: float(),
            quantity: integer(),
            discount: float(),
            total: float()
          }
  end

  defmodule User do
    @moduledoc """
    Represents a user from JSON files.
    """
    @enforce_keys [:id, :name, :email]
    defstruct [:id, :name, :email, :active, :last_access]

    @type t :: %__MODULE__{
            id: integer(),
            name: String.t(),
            email: String.t(),
            active: boolean(),
            last_access: String.t() | nil
          }
  end

  defmodule Session do
    @moduledoc """
    Represents a user session from JSON files.
    """
    @enforce_keys [:user_id]
    defstruct [:user_id, :start, :duration_seconds, :pages_visited, :actions]

    @type t :: %__MODULE__{
            user_id: integer(),
            start: String.t() | nil,
            duration_seconds: integer() | nil,
            pages_visited: integer() | nil,
            actions: list(String.t())
          }
  end

  defmodule LogEntry do
    @moduledoc """
    Represents a log entry from LOG files.
    """
    @enforce_keys [:level, :component, :message]
    defstruct [:timestamp, :level, :component, :message, :hour]

    @type t :: %__MODULE__{
            timestamp: String.t() | nil,
            level: String.t(),
            component: String.t(),
            message: String.t(),
            hour: integer() | nil
          }
  end

  defmodule FileResult do
    @moduledoc """
    Result of processing a single file.

    This is the "unit of work" that flows through the system.
    Each file produces one FileResult, regardless of success or failure.
    """
    @enforce_keys [:path, :type, :filename]
    defstruct [
      :path,
      :type,
      :filename,
      status: :ok,
      metrics: %{},
      errors: [],
      duration_ms: 0,
      lines_processed: 0,
      lines_failed: 0
    ]

    @type status :: :ok | :error | :partial
    @type file_type :: :csv | :json | :log | :xml

    @type t :: %__MODULE__{
            path: String.t(),
            type: file_type(),
            filename: String.t(),
            status: status(),
            metrics: map(),
            errors: list({integer(), String.t()} | String.t()),
            duration_ms: integer(),
            lines_processed: integer(),
            lines_failed: integer()
          }

    @doc """
    Create a new FileResult for a given path and type.
    """
    def new(path, type) do
      %__MODULE__{
        path: path,
        type: type,
        filename: Path.basename(path)
      }
    end

    @doc """
    Mark a FileResult as successful with metrics.
    """
    def success(result, metrics, duration_ms, lines_processed \\ 0) do
      %{result |
        status: :ok,
        metrics: metrics,
        duration_ms: duration_ms,
        lines_processed: lines_processed
      }
    end

    @doc """
    Mark a FileResult as failed with errors.
    """
    def error(result, errors, duration_ms \\ 0)

    def error(result, errors, duration_ms) when is_list(errors) do
      %{result |
        status: :error,
        errors: errors,
        duration_ms: duration_ms
      }
    end

    def error(result, error, duration_ms) when is_binary(error) do
      error(result, [error], duration_ms)
    end

    @doc """
    Mark a FileResult as partially successful.
    """
    def partial(result, metrics, errors, duration_ms, lines_processed, lines_failed) do
      %{result |
        status: :partial,
        metrics: metrics,
        errors: errors,
        duration_ms: duration_ms,
        lines_processed: lines_processed,
        lines_failed: lines_failed
      }
    end
  end

  defmodule ExecutionReport do
    @moduledoc """
    Executive summary of the entire execution.

    Aggregates all FileResults and provides overall statistics.
    Can optionally include benchmark comparison data.
    """
    @enforce_keys [:mode, :start_time]
    defstruct [
      :mode,
      :start_time,
      :directory,
      :benchmark_data,
      :report_path,
      total_files: 0,
      csv_count: 0,
      json_count: 0,
      log_count: 0,
      xml_count: 0,
      success_count: 0,
      error_count: 0,
      partial_count: 0,
      total_duration_ms: 0,
      results: []
    ]

    @type t :: %__MODULE__{
            mode: String.t(),
            start_time: DateTime.t(),
            directory: String.t() | nil,
            benchmark_data: map() | nil,
            total_files: integer(),
            csv_count: integer(),
            json_count: integer(),
            log_count: integer(),
            xml_count: integer(),
            success_count: integer(),
            error_count: integer(),
            partial_count: integer(),
            total_duration_ms: integer(),
            results: list(FileResult.t())
          }

    @doc """
    Create a new ExecutionReport.
    """
    def new(mode, start_time) do
      %__MODULE__{
        mode: mode,
        start_time: start_time
      }
    end

    @doc """
    Calculate success rate as a percentage.
    """
    def success_rate(%__MODULE__{total_files: 0}), do: 0.0
    def success_rate(%__MODULE__{total_files: total, success_count: success, partial_count: partial}) do
      ((success + partial) / total * 100) |> Float.round(1)
    end
  end
end
