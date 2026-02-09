# FProcess Architecture Documentation

## Table of Contents

- [Overview](#overview)
- [Design Principles](#design-principles)
- [System Architecture](#system-architecture)
- [Module Dependency Graph](#module-dependency-graph)
- [Data Flow](#data-flow)
- [Concurrency Model](#concurrency-model)
- [Error Handling Strategy](#error-handling-strategy)
- [Performance Considerations](#performance-considerations)

## Overview

FProcess is designed as a scalable, fault-tolerant file processing system that leverages Elixir's concurrency primitives to achieve high throughput while maintaining code clarity and maintainability.

### Core Design Goals

1. **Scalability**: Handle thousands of files efficiently
2. **Reliability**: Graceful error handling without cascading failures
3. **Maintainability**: Clear module boundaries and responsibilities
4. **Performance**: Maximize CPU utilization through parallelism
5. **Extensibility**: Easy addition of new file formats

## Design Principles

### Separation of Concerns

Each module has a single, well-defined responsibility:

- **CLI**: User interface and argument parsing
- **Core**: Orchestration and workflow coordination
- **Parsers**: File format interpretation
- **Metrics**: Business logic and analytics
- **Modes**: Execution strategies
- **Report**: Output generation

### Functional Programming Paradigm

- **Immutability**: All data structures are immutable
- **Pure Functions**: Side effects isolated to specific modules (I/O, reporting)
- **Pattern Matching**: Extensive use for control flow and data destructuring
- **Higher-Order Functions**: Map, reduce, filter for data transformations

### Error Handling Philosophy

- **Let It Crash**: Failed file processing doesn't affect other files
- **Explicit Error Types**: Structured error tuples for pattern matching
- **Graceful Degradation**: Partial success reporting
- **Detailed Error Messages**: Include file name, line number, and context

## System Architecture

### Layered Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        CLI Layer                            │
│  (Argument parsing, validation, help messages)              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                     Orchestration Layer                     │
│  (Core module: workflow coordination, mode selection)       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Processing Modes Layer                   │
│  (Sequential, Parallel, Benchmark implementations)          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  File Processing Pipeline                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │Discovery │→ │ Parsing  │→ │Validation│→ │ Metrics  │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      Output Layer                           │
│  (Report generation, console UI, file writing)              │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

#### CLI Layer

**Module**: `FProcess.CLI`

**Responsibilities**:
- Parse command-line arguments using OptionParser
- Validate input paths and options
- Display help messages and usage examples
- Convert user input to internal configuration structure

**Key Functions**:
- `main/1`: Entry point for escript
- `parse_args/1`: Argument parsing and validation
- `show_help/0`: Display comprehensive help text

#### Orchestration Layer

**Module**: `FProcess.Core`

**Responsibilities**:
- Coordinate overall execution flow
- File discovery and classification
- Mode selection and delegation
- Report generation and saving

**Key Functions**:
- `run/1`: Main execution coordinator
- `process_with_mode/2`: Delegate to appropriate mode
- `save_report/2`: Persist execution report

**Module**: `FProcess.FileDiscovery`

**Responsibilities**:
- Scan directories recursively
- Classify files by extension
- Filter supported formats
- Return file lists with metadata

**Key Functions**:
- `discover/1`: Find all processable files
- `classify_file/1`: Determine file type

#### Processing Modes Layer

**Module**: `FProcess.Modes.Sequential`

**Characteristics**:
- Processes files one at a time
- Lower memory footprint
- Predictable resource usage
- Simpler debugging

**Implementation**:
```elixir
files
|> Enum.map(&FileProcessor.process(&1, config))
|> collect_results()
```

**Module**: `FProcess.Modes.Parallel`

**Characteristics**:
- Concurrent processing with Task.async_stream
- Fixed worker pool (configurable)
- Automatic load balancing
- Per-file timeout enforcement

**Implementation**:
```elixir
files
|> Task.async_stream(
     &FileProcessor.process(&1, config),
     max_concurrency: config.max_workers,
     timeout: config.timeout_ms,
     on_timeout: :kill_task
   )
|> Enum.to_list()
```

**Module**: `FProcess.Modes.Benchmark`

**Characteristics**:
- Runs both sequential and parallel modes
- Measures execution time and memory
- Calculates speedup factor
- Generates comparison report

**Metrics Collected**:
- Sequential duration (seconds)
- Parallel duration (seconds)
- Memory usage (KB)
- Speedup factor (sequential / parallel)
- Number of processes used

#### File Processing Pipeline

**Module**: `FProcess.FileProcessor`

**Pipeline Stages**:

1. **Type Detection**
   - Determine file type from extension
   - Select appropriate parser

2. **Parsing**
   - Delegate to type-specific parser
   - Handle parsing errors
   - Return structured data or error

3. **Validation**
   - Verify data integrity
   - Check required fields
   - Validate data types

4. **Metrics Extraction**
   - Compute analytics
   - Generate statistics
   - Return metrics map

5. **Result Assembly**
   - Package into FileResult struct
   - Include status, metrics, errors
   - Add timing information

**Retry Mechanism**:
```elixir
def process_with_retry(file, config, attempt \\ 1) do
  case process_file(file, config) do
    {:ok, result} -> result
    {:error, _} when attempt < config.max_retries ->
      :timer.sleep(exponential_backoff(attempt))
      process_with_retry(file, config, attempt + 1)
    {:error, error} ->
      error_result(file, error)
  end
end
```

#### Parser Layer

**Common Interface**:
All parsers implement:
```elixir
@spec parse(String.t()) :: {:ok, term()} | {:error, String.t()}
```

**CSV Parser** (`FProcess.Parsers.CSVParser`):
- Library: NimbleCSV
- Validation: Type checking, required fields
- Error handling: Line-level error reporting

**JSON Parser** (`FProcess.Parsers.JSONParser`):
- Library: Jason
- Schema detection: Automatic structure recognition
- Error handling: Syntax errors with position

**LOG Parser** (`FProcess.Parsers.LogParser`):
- Pattern: Regex-based line parsing
- Formats: Standard log format (timestamp, level, component, message)
- Error handling: Invalid format detection

**XML Parser** (`FProcess.Parsers.XMLParser`):
- Library: SweetXml
- XPath: Declarative element extraction
- Error handling: Well-formedness validation

#### Metrics Layer

**Common Interface**:
All metrics modules implement:
```elixir
@spec extract(parsed_data) :: map()
```

**CSV Metrics**:
- Sales totals and averages
- Product performance analysis
- Category rankings
- Temporal analysis (date ranges)

**JSON Metrics**:
- User statistics (active/inactive)
- Session analytics
- Action frequency analysis
- Temporal patterns (peak hours)

**LOG Metrics**:
- Severity distribution
- Error pattern analysis
- Component error rates
- Temporal distribution

**XML Metrics**:
- Element counting
- Inventory calculations
- Price analysis
- Stock level monitoring

#### Output Layer

**Module**: `FProcess.Report`

**Responsibilities**:
- Format execution report
- Generate metrics sections by type
- Format error messages (line wrapping)
- Add performance statistics

**Report Structure**:
```
Header
├── Metadata (timestamp, directory, mode)
└── Summary
    ├── File counts by type
    ├── Success/error statistics
    └── Execution time

Metrics Sections (per type)
├── Individual file results
│   ├── Success: metrics display
│   └── Error: formatted error messages
└── Consolidated totals

Performance Section
├── Execution time
├── Average per file
└── Benchmark comparison (if available)
```

**Module**: `FProcess.UI`

**Responsibilities**:
- Console output formatting
- Progress bar management
- Real-time status updates
- Single-file metrics display

## Module Dependency Graph

```
FProcess.CLI
    ↓
FProcess.Core
    ↓
    ├─→ FProcess.FileDiscovery
    ├─→ FProcess.Modes.Sequential ─→ FProcess.FileProcessor
    ├─→ FProcess.Modes.Parallel   ─→ FProcess.FileProcessor
    ├─→ FProcess.Modes.Benchmark  ─→ Sequential + Parallel
    ├─→ FProcess.Report
    └─→ FProcess.UI

FProcess.FileProcessor
    ├─→ FProcess.Parsers.CSVParser  ─→ FProcess.Metrics.CSVMetrics
    ├─→ FProcess.Parsers.JSONParser ─→ FProcess.Metrics.JSONMetrics
    ├─→ FProcess.Parsers.LogParser  ─→ FProcess.Metrics.LogMetrics
    └─→ FProcess.Parsers.XMLParser  ─→ FProcess.Metrics.XMLMetrics

FProcess.Structs
    └─→ (Used by all modules for data structures)

FProcess.Utils.Config
    └─→ (Used by Core, Modes for configuration)

FProcess.Utils.Progress
    └─→ (Used by Modes for progress tracking)
```

## Data Flow

### High-Level Flow

```
User Input (CLI)
    ↓
Configuration Building
    ↓
File Discovery
    ↓
Mode Selection
    ↓
    ├─→ Sequential Processing
    │       ↓
    │   File Processing Pipeline (one at a time)
    │       ↓
    │   Results Collection
    │
    └─→ Parallel Processing
            ↓
        Task Pool Creation
            ↓
        File Processing Pipeline (concurrent)
            ↓
        Results Collection
    ↓
Report Generation
    ↓
Console Output + File Writing
```

### File Processing Pipeline (Detailed)

```
Input: File Path
    ↓
┌─────────────────────┐
│  Type Detection     │
│  (by extension)     │
└─────────────────────┘
    ↓
┌─────────────────────┐
│  Parser Selection   │
│  (CSV/JSON/LOG/XML) │
└─────────────────────┘
    ↓
┌─────────────────────┐
│  File Reading       │
│  (File.read!)       │
└─────────────────────┘
    ↓
┌─────────────────────┐
│  Parsing            │
│  {:ok, data} or     │
│  {:error, reason}   │
└─────────────────────┘
    ↓
    ├─→ Success Path
    │   ┌─────────────────────┐
    │   │  Validation         │
    │   │  (data integrity)   │
    │   └─────────────────────┘
    │       ↓
    │   ┌─────────────────────┐
    │   │  Metrics Extraction │
    │   │  (analytics)        │
    │   └─────────────────────┘
    │       ↓
    │   ┌─────────────────────┐
    │   │  FileResult         │
    │   │  status: :ok        │
    │   │  metrics: %{}       │
    │   └─────────────────────┘
    │
    └─→ Error Path
        ┌─────────────────────┐
        │  Error Handling     │
        │  (retry logic)      │
        └─────────────────────┘
            ↓
        ┌─────────────────────┐
        │  FileResult         │
        │  status: :error     │
        │  errors: [...]      │
        └─────────────────────┘
```

### Data Structures

**FileInfo**:
```elixir
%FileInfo{
  path: String.t(),
  type: :csv | :json | :log | :xml,
  size: integer()
}
```

**FileResult**:
```elixir
%FileResult{
  filename: String.t(),
  type: atom(),
  status: :ok | :error | :partial,
  metrics: map(),
  errors: list(),
  duration_ms: integer()
}
```

**ExecutionReport**:
```elixir
%ExecutionReport{
  mode: :sequential | :parallel | :benchmark,
  total_files: integer(),
  success_count: integer(),
  error_count: integer(),
  partial_count: integer(),
  results: [FileResult.t()],
  total_duration_ms: integer(),
  benchmark_data: map() | nil,
  timestamp: DateTime.t()
}
```

## Concurrency Model

### Process Architecture

```
Main Process (CLI/Core)
    ↓
    ├─→ Progress Tracker Process
    │   └─→ Updates progress bar periodically
    │
    └─→ Task Supervisor (implicit via Task.async_stream)
            ↓
        Worker Pool (fixed size)
            ↓
        ├─→ Worker 1 (File Task)
        ├─→ Worker 2 (File Task)
        ├─→ Worker 3 (File Task)
        └─→ ... (up to max_workers)
```

### Parallel Processing Strategy

**Task.async_stream Configuration**:
```elixir
Task.async_stream(
  files,
  &process_file/1,
  max_concurrency: 8,      # Fixed worker pool
  timeout: 30_000,          # Per-task timeout
  on_timeout: :kill_task,   # Kill hung tasks
  ordered: false            # Results in completion order
)
```

**Benefits**:
- Automatic worker pool management
- Built-in timeout handling
- Process isolation (failures don't propagate)
- Back-pressure handling (queue management)

### Synchronization Points

1. **File Discovery**: Sequential (fast operation)
2. **Processing**: Parallel (CPU/IO intensive)
3. **Results Collection**: Sequential (aggregation)
4. **Report Generation**: Sequential (single file write)

### Memory Management

- **Streaming**: Results collected lazily with Enum.to_list
- **Garbage Collection**: Per-task GC when process terminates
- **Memory Bounds**: Fixed worker pool prevents unbounded process creation

## Error Handling Strategy

### Error Categories

1. **Parsing Errors**: Invalid file format, syntax errors
2. **Validation Errors**: Data integrity violations
3. **IO Errors**: File not found, permission denied
4. **Timeout Errors**: Processing exceeded time limit
5. **System Errors**: Out of memory, process crashes

### Error Recovery

**Retry Logic**:
```elixir
defp exponential_backoff(attempt) do
  base_delay = 100  # milliseconds
  max_delay = 5000
  delay = min(base_delay * :math.pow(2, attempt - 1), max_delay)
  trunc(delay)
end
```

**Retry Conditions**:
- IO errors (transient)
- Timeout errors (may succeed with more time)
- Not retried: Parsing errors (deterministic failures)

### Error Reporting

**Granularity Levels**:
1. **Console**: Brief error summary (truncated messages)
2. **Report**: Full error details with context
3. **Logs**: Detailed error stack traces (if verbose mode)

**Error Message Formatting**:
- Include file name
- Include line number (if applicable)
- Wrap long messages (80 character limit)
- Preserve error context

## Performance Considerations

### Bottleneck Analysis

**CPU-Bound Operations**:
- Parsing (especially CSV with validation)
- Metrics computation
- Report formatting

**IO-Bound Operations**:
- File reading
- Report writing
- Progress bar updates

### Optimization Techniques

**Lazy Evaluation**:
```elixir
# Stream-based processing for memory efficiency
Stream.map(files, &process/1)
|> Stream.filter(&success?/1)
|> Enum.to_list()
```

**Progress Bar Overhead Mitigation**:
- Update frequency throttling
- Separate process for UI updates
- Disabled in benchmark mode

**Worker Pool Sizing**:
- Default: 8 workers (balanced for typical systems)
- Recommendation: CPU cores × 2 for CPU-bound
- Recommendation: CPU cores × 4 for IO-bound

### Memory Profile

**Per-File Memory**:
- CSV (1000 rows): ~500 KB
- JSON (100 records): ~200 KB
- LOG (10000 lines): ~1 MB
- XML (100 elements): ~300 KB

**Total Memory Usage**:
- Sequential: O(1) - single file in memory
- Parallel (N workers): O(N) - N files in memory simultaneously

### Scalability Limits

**Tested Scenarios**:
- 10,000 files: 7 seconds (parallel, 16 workers)
- 100,000 files: Not tested (would require streaming report generation)

**Theoretical Limits**:
- File count: Limited by available memory for results list
- File size: Limited by available memory and timeout
- Worker count: Limited by system schedulers and memory

### Performance Monitoring

**Benchmark Metrics**:
- Execution time (sequential vs parallel)
- Memory usage (peak during processing)
- Speedup factor (parallel improvement)
- Throughput (files per second)

**Profiling Tools**:
```bash
# Built-in benchmark
./fprocess data --benchmark

# External profiling
mix profile.fprof
mix profile.eprof
:observer.start()  # In IEx
```

## Extension Points

### Adding New File Types

1. Create parser module implementing `parse/1`
2. Create metrics module implementing `extract/1`
3. Update `FileProcessor.process_file/2` with new type
4. Add report formatting in `Report` module
5. Update help text in CLI

### Adding New Processing Modes

1. Create module in `lib/f_process/modes/`
2. Implement `process/2` function
3. Update `Core.process_with_mode/2`
4. Add CLI option parsing

### Adding New Metrics

1. Update relevant metrics module
2. Add computation in `extract/1`
3. Update report formatting
4. Document in README

## Testing Strategy

### Unit Tests

- Parser modules: Valid and invalid inputs
- Metrics modules: Edge cases and calculations
- Utility functions: Boundary conditions

### Integration Tests

- End-to-end processing
- Multi-file scenarios
- Error recovery paths

### Performance Tests

- Large file handling
- High concurrency stress tests
- Memory leak detection

### Test Data

- Valid samples: Representative real-world data
- Error samples: Common failure modes
- Edge cases: Boundary conditions
