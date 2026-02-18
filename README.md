# FProcess - File Processing System

Comprehensive parallel file processing system with web interface and CLI, built with Elixir and Phoenix Framework.

## Overview

FProcess is an Elixir **Umbrella** application that processes multiple file types (CSV, JSON, XML, LOG) in parallel, generating detailed metrics and analytical reports. The system is designed with a clean architecture that separates business logic (Core) from presentation (Web).

### Main Features

- **Parallel Processing**: Leverages Elixir/BEAM concurrency to process files simultaneously
- **Multiple Formats**: Native support for CSV, JSON, XML, and LOG files
- **Modern Web Interface**: Elegant UI built with Phoenix controllers and Tailwind CSS
- **Robust CLI**: Command-line tool for automation
- **Benchmark Mode**: Compares sequential vs parallel performance
- **Detailed Analysis**: Format-specific metrics extraction
- **Error Handling**: Robust error detection and reporting system
- **Session Management**: Efficient storage with ETS to avoid cookie overflow

---

## Umbrella Architecture

### Why Umbrella?

This project uses an Elixir **Umbrella architecture**, which means it's divided into multiple independent but coordinated applications:

```
f_process/
├── apps/
│   ├── core/      # Pure business logic
│   └── web/       # Phoenix web interface
├── config/        # Shared configuration
└── deps/          # Shared dependencies
```

#### Umbrella Advantages in This Project

1. **Separation of Concerns**
   - `core`: All processing logic, no web dependencies
   - `web`: Only presentation and HTTP handling
   - Each app has a clearly defined purpose

2. **Core Reusability**
   - CLI uses Core directly
   - Web also uses the same Core
   - **Same logic, multiple interfaces** (DRY principle)

3. **Independent Testing**
   - Core tests don't depend on Phoenix
   - Web tests can use Core mocks
   - Faster test suites

4. **Flexible Deployment**
   - Could deploy only Core as a service
   - Or only Web on a different server
   - Or both together (current configuration)

5. **Scalability**
   - Easy to add new interfaces: GraphQL API, gRPC, etc.
   - Each would be a new app in the umbrella
   - Core remains intact

---

## Technologies Used

### Backend
- **Elixir 1.19.4**: Functional and concurrent language
- **Phoenix 1.8.3**: Modern web framework (traditional MVC architecture)
- **ETS (Erlang Term Storage)**: In-memory storage for sessions
- **Bandit**: High-performance HTTP/2 server

### Frontend
- **Tailwind CSS v4**: Utility-first CSS framework
- **esbuild**: Ultra-fast JavaScript bundler
- **HEEx Templates**: Phoenix's safe and efficient templates

### Processing Libraries
- **NimbleCSV**: Fast and efficient CSV parser
- **Jason**: Optimized JSON encoder/decoder
- **SweetXml**: XML processing with XPath
- **Req**: Modern HTTP client for Elixir

---

## Project Structure

### Core App (`apps/core/`)

The **core** is the system's heart, completely independent of any interface:

```
apps/core/
├── lib/
│   └── f_process/
│       ├── cli.ex                  # Command-line interface
│       ├── core.ex                 # Main orchestrator
│       ├── file_discovery.ex       # File discovery and classification
│       ├── report.ex               # Report generator
│       ├── modes/
│       │   ├── sequential.ex       # Sequential processing
│       │   ├── parallel.ex         # Parallel processing
│       │   └── benchmark.ex        # Comparative mode
│       ├── parsers/
│       │   ├── csv_parser.ex       # CSV-specific parser
│       │   ├── json_parser.ex      # JSON-specific parser
│       │   ├── log_parser.ex       # LOG-specific parser
│       │   └── xml_parser.ex       # XML-specific parser
│       └── structs/
│           ├── execution_report.ex # Report structure
│           └── file_result.ex      # Per-file result
```

#### Core Processing Flow

1. **FileDiscovery**: Scans directories, classifies files by extension
2. **Core**: Orchestrates processing mode (sequential/parallel/benchmark)
3. **Modes**: Execute processing according to selected mode
4. **Parsers**: Each parser extracts format-specific metrics
5. **Report**: Generates consolidated report in text format

### Web App (`apps/web/`)

The **web** application is a thin wrapper around Core:

```
apps/web/
├── lib/
│   ├── web/
│   │   └── application.ex          # Initialization (creates ETS table)
│   └── web_web/
│       ├── controllers/
│       │   ├── page_controller.ex  # Route logic and actions
│       │   └── page_html/
│       │       ├── home.html.heex      # Upload page
│       │       ├── results.html.heex   # Detailed results
│       │       ├── errors.html.heex    # Error page
│       │       └── benchmark.html.heex # Benchmark view
│       ├── components/
│       │   ├── core_components.ex  # Reusable components
│       │   └── layouts.ex          # Application layouts
│       └── router.ex               # Route definitions
└── assets/
    ├── css/
    │   └── app.css                 # Tailwind styles
    └── js/
        └── app.js                  # Minimal JavaScript
```

---

## Web Architecture - Design and Decisions

### Core Principle: "Thin Web, Fat Core"

The web application follows the principle of **keeping the web layer thin**:

```elixir
# BAD: Logic in controller
def upload(conn, params) do
  files = params["files"]
  results = Enum.map(files, fn file ->
    # Processing logic here... (BAD)
  end)
end

# GOOD: Web only orchestrates, Core processes
def upload(conn, params) do
  temp_files = create_temp_files(params["archivos"])
  {:ok, report} = FProcess.process_files(temp_files, mode: :parallel)
  render(conn, :results, report: report)
end
```

### Controller Modules

The `PageController` has **well-defined actions**:

#### 1. `home/2` - Home Page
```elixir
def home(conn, _params)
```
- Renders upload form
- Stateless, always shows clean interface

#### 2. `upload/2` - Process Files (Normal Modes)
```elixir
def upload(conn, %{"archivos" => archivos, "processing_mode" => mode})
```
**Flow**:
1. Creates temporary files (Phoenix uploads in `/tmp/`)
2. Calls `FProcess.process_files(temp_files, opts)`
3. Generates unique `report_id`
4. Saves report in **ETS** (not in session/cookie)
5. Saves only `report_id` in session (~22 bytes)
6. Renders results page

**Why ETS?**
- Phoenix sessions use cookies (limit: 4096 bytes)
- A report with 7 files can weigh >10KB
- ETS stores in server RAM
- Session only saves small ID

#### 3. `benchmark_results/2` - Benchmark Mode
```elixir
def benchmark_results(conn, %{"archivos" => archivos})
```
**Difference from `upload/2`**:
- Doesn't save in ETS (no subsequent navigation needed)
- Uses `benchmark: true` option instead of `mode: :parallel`
- Renders benchmark view directly
- Shows sequential vs parallel comparison

#### 4. `results/2` - View Saved Results
```elixir
def results(conn, _params)
```
**Flow**:
1. Reads `report_id` from session
2. Looks up in ETS: `:ets.lookup(:reports_store, report_id)`
3. If exists: render results
4. If not: redirect to home with error message

#### 5. `errors/2` - Detailed Error Page
```elixir
def errors(conn, _params)
```
- Same flow as `results/2`
- But renders error template
- Allows navigation: results ↔ errors ↔ results

### Web Design Decisions

#### 1. Page Separation

**Why separate pages for results and errors?**

Initially everything was on one page with tabs, but:
- Single page was very long (>800 lines of HTML)
- Difficult to maintain
- Complex tabs in HEEx
- Separation allows better organization
- Each page with clear purpose
- Simple navigation with buttons

#### 2. ETS Instead of Cookies

```elixir
# Initialization in application.ex
def start(_type, _args) do
  # Create ETS table at application startup
  :ets.new(:reports_store, [:set, :public, :named_table])
  
  children = [
    WebWeb.Endpoint,
    # ...
  ]
end

# Usage in controller
report_id = generate_report_id()  # "aB3xY9k..." (22 chars)
:ets.insert(:reports_store, {report_id, reporte, timestamp})
put_session(conn, :report_id, report_id)  # Only ID in cookie
```

**Advantages**:
- No size limit (report can weigh MBs)
- Ultra-fast access (RAM memory)
- Multiple simultaneous users without issues
- Session cookie remains small

**Accepted trade-offs**:
- Lost on server restart (acceptable for demo)
- Doesn't persist to disk (not required)
- Periodic cleanup could be implemented (optional)

#### 3. Temporary File Creation

```elixir
temp_files = Enum.map(archivos, fn archivo ->
  temp_path = System.tmp_dir!() <> "/" <> archivo.filename
  File.cp!(archivo.path, temp_path)
  temp_path
end)
```

**Why copy to temp?**
- Phoenix saves uploads in `/tmp/plug-XXX/` with random names
- Core needs extensions to classify files
- Solution: copy with original name to `/tmp/`
- Cleaned up after: `Enum.each(temp_files, &File.rm/1)`

#### 4. Modern HEEx Templates

All templates use **HEEx** (HTML + EEx) with modern features:

```heex
<%!-- HEEx comments --%>
<div class="bg-slate-900 rounded-3xl">
  <%!-- Simple interpolation --%>
  <p><%= @report.total_files %> files</p>
  
  <%!-- Conditionals --%>
  <%= if @report.error_count > 0 do %>
    <.link href={~p"/errors"}>View Errors</.link>
  <% end %>
  
  <%!-- Iteration --%>
  <%= for result <- @report.results do %>
    <div><%= result.filename %></div>
  <% end %>
</div>
```

**Features used**:
- `<.link>` Phoenix component
- `~p"/path"` sigil for verified routes
- `{...}` interpolation in attributes
- `<%= ... %>` interpolation in content
- Tailwind classes directly in HTML

---

## Installation and Usage

### Prerequisites

- Elixir 1.19+ and Erlang/OTP 27+
- Node.js 18+ (for assets)

### Installation

```bash
# Clone repository
git clone <repository-url>
cd f_process

# Install dependencies
mix deps.get

# Install asset dependencies
cd apps/web/assets && npm install && cd ../../..

# Compile
mix compile
```

### Usage - Web Interface

```bash
# Start Phoenix server
mix phx.server

# Or in interactive mode
iex -S mix phx.server
```

Open browser at `http://localhost:4000`

**Web usage flow**:
1. Select files (CSV, JSON, XML, LOG)
2. Choose mode: Sequential, Parallel, or Benchmark
3. Click "PROCESS FILES"
4. View results with detailed metrics
5. (Optional) Click "View Errors" if there are issues

### Usage - CLI

```bash
# Compile CLI
cd apps/core
mix escript.build

# Process directory
./fprocess data/valid/

# With options
./fprocess data/valid/ --mode sequential
./fprocess data/valid/ --benchmark
./fprocess data/valid/ -b -v  # benchmark + verbose

# View help
./fprocess --help
```

---

## Processing Features

### Metrics by File Type

#### CSV (Sales)
- Consolidated sales total
- Unique products and best sellers
- Categories with highest revenue
- Average discounts
- Date ranges

#### JSON (Users/Sessions)
- Active vs inactive users
- Average session duration
- Top 5 most common actions
- Peak activity hours

#### LOG (System/Application)
- Distribution by level (DEBUG, INFO, WARN, ERROR, FATAL)
- Most frequent errors
- Components with most errors
- Total critical errors

#### XML (Products/Inventory)
- Total products
- Total inventory value
- Low stock items (<10)
- Average price

### Benchmark Mode

Compares performance between sequential and parallel processing:

```
BENCHMARK SUMMARY
Total files: 7
Sequential: 43 ms (avg 6.14 ms/file) - Success: 7
Parallel:   8 ms (avg 1.14 ms/file) - Success: 7
Speedup: 5.38x | Time saved: 35 ms (81.4%)
```

**Note on consistency**: 
- First web execution: realistic times (cold VM)
- Subsequent executions: faster (warm VM with JIT)
- **For reliable benchmarks**: use CLI or restart server

---

## UI/UX Design

### Color Palette

- **Background**: slate-950 (almost black)
- **Cards**: slate-900 with slate-800 borders
- **Accents**: indigo-600 (primary), emerald-500 (success), rose-500 (error)
- **Text**: slate-200 (primary), slate-400 (secondary)

### Key Components

- **Rounded cards** (rounded-3xl): Modern and smooth aesthetics
- **Micro-interactions**: Hover states, smooth transitions
- **Typography**: Font-black for titles, font-mono for metrics
- **Responsive grid**: Adaptable to mobile, tablet, desktop

---

## Configuration

### Processing Modes

```elixir
# In build_processing_options/1 of controller
case mode do
  "sequential" -> [mode: :sequential]
  "parallel"   -> [mode: :parallel]
  "benchmark"  -> [benchmark: true]
end
```

### Environment Variables

See `config/runtime.exs` for production configuration:
- `PHX_HOST`: Server host
- `PORT`: Port (default: 4000)
- `SECRET_KEY_BASE`: Secret key for sessions

---

## Testing

```bash
# Core tests
cd apps/core
mix test

# Web tests
cd apps/web
mix test

# Full umbrella tests
mix test
```

---

## Contributing

This project was developed as an Elixir architecture practice with Phoenix. Contributions are welcome following these guidelines:

1. Fork the project
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes with descriptive messages (see recent commits as example)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## License

This project is open source under the MIT license.

---

## Acknowledgments

- **Phoenix Framework** for excellent documentation
- **Elixir Community** for robust libraries
- **Tailwind CSS** for making design faster and maintainable

---

**Built with love and Elixir**

