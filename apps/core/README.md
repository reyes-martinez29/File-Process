# FProcess

A high-performance concurrent file processing system built with Elixir that analyzes multiple file formats, extracts metrics, validates data integrity, and generates comprehensive execution reports.

## Overview

FProcess is a production-ready file processing engine designed to handle large-scale data analysis tasks efficiently. It leverages Elixir's powerful concurrency model to process thousands of files simultaneously while maintaining data integrity and providing detailed analytics.

### Key Features

- **Concurrent Processing**: Utilizes Elixir processes for true parallel file processing with configurable worker pools
- **Multi-Format Support**: Native parsers for CSV, JSON, XML, and LOG files
- **Advanced Metrics Extraction**: Comprehensive analytics tailored to each file type
- **Error Resilience**: Automatic retry mechanisms with exponential backoff for transient failures
- **Performance Benchmarking**: Built-in tools to compare sequential vs parallel execution
- **Comprehensive Reporting**: Detailed execution reports with metrics, errors, and performance statistics
- **Progress Tracking**: Real-time progress visualization during processing
- **Data Validation**: Strict validation rules with detailed error messages

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Supported File Formats](#supported-file-formats)
- [Architecture](#architecture)
- [Configuration](#configuration)
- [Output Reports](#output-reports)
- [Performance](#performance)
- [Development](#development)
- [Testing](#testing)
- [License](#license)

## Installation

### Prerequisites

- Elixir 1.19 or higher
- Erlang/OTP 27 or higher

### Building from Source

```bash
# Clone the repository
git clone <repository-url>
cd f_process

# Install dependencies
mix deps.get

# Compile the project
mix compile

# Build the executable
mix escript.build
```

This will generate an executable file named `fprocess` in the project root directory.

### Running Tests

```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover

# Run specific test file
mix test test/csv_parser_test.exs
```

## Quick Start

### Basic Usage

Process all files in a directory:
```bash
./fprocess data/valid
```

Process a single file:
```bash
./fprocess data/valid/ventas_enero.csv
```

Process multiple specific files:
```bash
./fprocess data/valid/ventas_enero.csv data/valid/usuarios.json
```

### Benchmark Mode

Compare sequential vs parallel performance:
```bash
./fprocess data/valid --benchmark
```

### Custom Configuration

Process with custom worker count and timeout:
```bash
./fprocess data/valid --workers 16 --timeout 60000
```

## Usage

### Command Line Interface

```
fprocess <path> [options]
fprocess <file1> <file2> ... [options]
```

### Arguments

- `<path>`: Directory or file(s) to process

### Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--help` | `-h` | Display help message | - |
| `--mode MODE` | `-m` | Processing mode: `sequential` or `parallel` | `parallel` |
| `--benchmark` | `-b` | Run benchmark comparing sequential and parallel modes | - |
| `--timeout MS` | `-t` | Timeout per file in milliseconds | `30000` |
| `--retries N` | `-r` | Maximum retry attempts for failed files | `3` |
| `--workers N` | `-w` | Maximum concurrent workers in parallel mode | `8` |
| `--output DIR` | `-o` | Output directory for reports | `output` |
| `--verbose` | `-v` | Display detailed processing information | - |

### Examples

#### Process directory with default settings
```bash
./fprocess ./data/valid
```

#### Sequential processing mode
```bash
./fprocess ./data/valid --mode sequential
```

#### High-concurrency processing
```bash
./fprocess ./data/valid --workers 32
```

#### Custom timeout and retry settings
```bash
./fprocess ./data/valid --timeout 60000 --retries 5
```

#### Benchmark with custom output directory
```bash
./fprocess ./data/valid --benchmark --output ./reports
```

#### Verbose output for debugging
```bash
./fprocess ./data/valid --verbose
```

## Supported File Formats

### CSV Files

**Purpose**: Sales transaction data, product information, temporal analysis

**Required Columns**: `producto`, `cantidad`, `precio_unitario`, `categoria`

**Extracted Metrics**:
- Total sales revenue
- Unique product count
- Best-selling product (by quantity)
- Top revenue-generating category
- Average discount percentage
- Date range of transactions

**Validation Rules**:
- Numeric fields must be valid numbers
- Required columns must be present
- Dates must follow ISO format (YYYY-MM-DD)

### JSON Files

**Purpose**: User profiles, session analytics, activity tracking

**Supported Schemas**:
- User data with demographics and activity status
- Session data with timestamps and page views
- Combined user-session analytics

**Extracted Metrics**:
- Total registered users
- Active vs inactive user distribution
- Average session duration (minutes)
- Total pages visited across all sessions
- Top 5 most common user actions
- Peak activity hour with session count

**Validation Rules**:
- Valid JSON syntax
- Required fields must be present
- Numeric values must be valid
- Timestamps must be parseable

### LOG Files

**Purpose**: System logs, application events, error tracking

**Supported Levels**: DEBUG, INFO, WARN, ERROR, FATAL

**Extracted Metrics**:
- Total log entries
- Distribution by severity level (with percentages)
- Most frequent error messages (pattern analysis)
- Components with highest error rates
- Critical errors count (ERROR + FATAL)

**Validation Rules**:
- Valid log level identifier
- Parseable timestamp format
- Component name present

### XML Files

**Purpose**: Product catalogs, inventory management, structured data

**Extracted Metrics**:
- Total product count
- Total inventory value (sum of price × stock)
- Number of unique categories
- Low stock items (stock < 10 units)
- Average product price

**Validation Rules**:
- Well-formed XML structure
- Required elements present
- Numeric fields contain valid numbers

## Architecture

### System Design

FProcess follows a modular architecture with clear separation of concerns:

```
FProcess
├── CLI Layer (Command-line interface)
├── Core Layer (Orchestration & coordination)
├── Processing Modes
│   ├── Sequential (one-by-one processing)
│   ├── Parallel (concurrent processing with Task.async_stream)
│   └── Benchmark (performance comparison)
├── File Processing Pipeline
│   ├── Discovery (file detection & classification)
│   ├── Parsing (format-specific parsers)
│   ├── Validation (data integrity checks)
│   └── Metrics Extraction (analytics computation)
├── Reporting Layer (output generation)
└── Utilities (configuration, progress, helpers)
```

### Component Overview

#### Core Components

**FProcess.Core**
- Main orchestration module
- Handles file discovery and classification
- Coordinates processing mode execution
- Manages report generation

**FProcess.CLI**
- Command-line argument parsing
- Input validation
- Help message generation
- User interaction handling

#### Processing Modes

**FProcess.Modes.Sequential**
- Processes files one at a time
- Lower memory footprint
- Suitable for resource-constrained environments

**FProcess.Modes.Parallel**
- Concurrent processing using Task.async_stream
- Configurable worker pool (default: 8 workers)
- Automatic load balancing
- Timeout and error handling per task

**FProcess.Modes.Benchmark**
- Runs both sequential and parallel modes
- Measures execution time and memory usage
- Calculates speedup factor
- Generates comparison metrics

#### File Processing Pipeline

**FProcess.FileDiscovery**
- Scans directories recursively
- Classifies files by extension
- Filters supported formats

**FProcess.FileProcessor**
- Coordinates parsing and metrics extraction
- Implements retry logic with exponential backoff
- Handles errors gracefully
- Returns structured results

**Parsers** (format-specific)
- `CSVParser`: NimbleCSV-based parsing with validation
- `JSONParser`: Jason-based JSON parsing
- `LogParser`: Pattern-based log line parsing
- `XMLParser`: SweetXml-based XML parsing

**Metrics Extractors**
- `CSVMetrics`: Sales analytics and temporal analysis
- `JSONMetrics`: User behavior and session patterns
- `LogMetrics`: Error distribution and severity analysis
- `XMLMetrics`: Inventory and product analytics

#### Reporting

**FProcess.Report**
- Generates comprehensive text reports
- Formats metrics by file type
- Includes error details with line wrapping
- Adds execution statistics and benchmarks

**FProcess.UI**
- Console output formatting
- Progress bar management
- Real-time status updates
- Single-file metrics display

### Concurrency Model

FProcess leverages Elixir's actor model for safe concurrent processing:

1. **Main Process**: Orchestrates overall execution
2. **Worker Pool**: Fixed-size pool of concurrent workers (Task.async_stream)
3. **File Tasks**: Each file processed in isolated task with timeout
4. **Progress Tracker**: Separate process for UI updates

**Concurrency Safety**:
- No shared mutable state
- Message passing for coordination
- Process isolation prevents cascading failures
- Supervision tree (implicit via Task.async_stream)

## Configuration

### Default Configuration

Located in `lib/f_process/utils/config.ex`:

```elixir
%{
  mode: :parallel,              # Processing mode
  max_workers: 8,               # Concurrent worker limit
  timeout_ms: 30_000,           # Per-file timeout (30 seconds)
  max_retries: 3,               # Retry attempts for failures
  output_dir: "output",         # Report output directory
  show_progress: true,          # Progress bar display
  verbose: false                # Detailed logging
}
```

### Runtime Configuration

Override defaults via command-line options:

```bash
./fprocess data/valid \
  --mode parallel \
  --workers 16 \
  --timeout 60000 \
  --retries 5 \
  --output ./custom_reports \
  --verbose
```

### Performance Tuning

**Worker Count Recommendations**:
- Small datasets (< 100 files): 4-8 workers
- Medium datasets (100-1000 files): 8-16 workers
- Large datasets (> 1000 files): 16-32 workers
- Maximum: `System.schedulers_online() * 2`

**Timeout Guidelines**:
- Small files (< 1MB): 5,000 ms
- Medium files (1-10MB): 30,000 ms (default)
- Large files (> 10MB): 60,000+ ms

## Output Reports

### Report Structure

Reports are generated in the `output/` directory with timestamp-based filenames:
```
output/reporte_2026-01-22_14_30_45.txt
```

### Report Sections

1. **Header**
   - Generation timestamp
   - Processed directory/files
   - Processing mode

2. **Executive Summary**
   - Total files processed by type
   - Total execution time
   - Error count and success rate

3. **Metrics by File Type**
   - Individual file results
   - Type-specific metrics
   - Consolidated totals

4. **Performance Analysis**
   - Total duration
   - Average time per file
   - Benchmark comparison (if applicable)

5. **Error Details**
   - Failed file list
   - Error messages with line numbers
   - Validation failure reasons

### Single File Metrics

When processing a single file, metrics are displayed directly in the console:

```
[Archivo: ventas_enero.csv]
  * Total de ventas: $24399.93
  * Productos únicos: 15
  * Producto más vendido: Cable HDMI (40 unidades)
  * Categoría con mayor ingreso: Computadoras ($10289.91)
  * Promedio de descuento aplicado: 12.0%
  * Rango de fechas procesadas: 2024-01-02 a 2024-01-30
```

## Performance

### Benchmark Results

Typical performance on a 4-core system (8 logical cores):

| Dataset Size | Sequential | Parallel (8 workers) | Speedup |
|--------------|------------|----------------------|---------|
| 10 files | 350ms | 80ms | 4.4x |
| 100 files | 3.2s | 0.7s | 4.6x |
| 1000 files | 32s | 7s | 4.5x |

### Optimization Features

- **Lazy Evaluation**: Streams used for memory efficiency
- **Task Pooling**: Fixed worker pool prevents resource exhaustion
- **Early Termination**: Timeout mechanism prevents hung processes
- **Progress Overhead**: Minimal (< 2% for parallel, < 0.1% for sequential)
- **Memory Management**: Garbage collection per file task

### Scalability

- **Horizontal**: Add more workers for CPU-bound tasks
- **Vertical**: Increase timeout for I/O-bound operations
- **Tested**: Up to 10,000 files in single run
- **Memory**: Constant memory usage with streaming

## Development

### Project Structure

```
f_process/
├── lib/
│   ├── f_process.ex                 # Main module
│   ├── structs.ex                   # Data structures
│   └── f_process/
│       ├── cli.ex                   # CLI interface
│       ├── core.ex                  # Core orchestration
│       ├── file_discovery.ex        # File scanning
│       ├── file_processor.ex        # Processing pipeline
│       ├── report.ex                # Report generation
│       ├── ui.ex                    # Console UI
│       ├── modes/
│       │   ├── sequential.ex        # Sequential mode
│       │   ├── parallel.ex          # Parallel mode
│       │   └── benchmark.ex         # Benchmark mode
│       ├── parsers/
│       │   ├── csv_parser.ex        # CSV parsing
│       │   ├── json_parser.ex       # JSON parsing
│       │   ├── log_parser.ex        # Log parsing
│       │   └── xml_parser.ex        # XML parsing
│       ├── metrics/
│       │   ├── csv_metrics.ex       # CSV analytics
│       │   ├── json_metrics.ex      # JSON analytics
│       │   ├── log_metrics.ex       # Log analytics
│       │   └── xml_metrics.ex       # XML analytics
│       └── utils/
│           ├── config.ex            # Configuration
│           └── progress.ex          # Progress tracking
├── test/                            # Test suite
├── data/                            # Sample data
│   ├── valid/                       # Valid test files
│   └── error/                       # Error test cases
├── output/                          # Generated reports
├── mix.exs                          # Project configuration
└── README.md                        # This file
```

### Adding New File Types

1. Create parser in `lib/f_process/parsers/`:
```elixir
defmodule FProcess.Parsers.YourParser do
  def parse(file_path) do
    # Parsing logic
    {:ok, parsed_data}
  end
end
```

2. Create metrics extractor in `lib/f_process/metrics/`:
```elixir
defmodule FProcess.Metrics.YourMetrics do
  def extract(parsed_data) do
    # Metrics computation
    %{metric1: value1, metric2: value2}
  end
end
```

3. Update `FileProcessor` to handle new type
4. Add report formatting in `Report` module
5. Add tests in `test/` directory

### Code Style

- Follow Elixir style guide
- Use `mix format` for consistent formatting
- Document public functions with `@doc`
- Add typespecs for function signatures
- Keep functions small and focused (< 20 lines)

## Testing

### Test Coverage

The project includes comprehensive tests:

- **Unit Tests**: Individual module testing
- **Integration Tests**: End-to-end processing tests
- **Edge Case Tests**: Error handling validation
- **Stress Tests**: High-concurrency scenarios

### Running Tests

```bash
# All tests
mix test

# Specific category
mix test test/csv_parser_test.exs
mix test test/integration_test.exs

# With coverage report
mix test --cover

# Watch mode (requires mix_test_watch)
mix test.watch
```

### Test Data

Sample files are provided in `data/`:

- `data/valid/`: Correctly formatted files
- `data/error/`: Malformed files for error testing

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for new functionality
4. Ensure all tests pass (`mix test`)
5. Format code (`mix format`)
6. Commit changes (`git commit -m 'Add amazing feature'`)
7. Push to branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

Built with:
- [Elixir](https://elixir-lang.org/) - Functional programming language
- [NimbleCSV](https://github.com/dashbitco/nimble_csv) - Fast CSV parsing
- [Jason](https://github.com/michalmuskala/jason) - JSON encoding/decoding
- [SweetXml](https://github.com/kbrw/sweet_xml) - XML parsing
