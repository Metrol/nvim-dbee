<!-- DOCGEN_IGNORE_START -->

<!-- This tag controlls what's ignored by the docgen workflow. -->

![Linting Status](https://img.shields.io/github/actions/workflow/status/kndndrj/nvim-dbee/lint.yml?label=linting&style=for-the-badge)
![Docgen Status](https://img.shields.io/github/actions/workflow/status/kndndrj/nvim-dbee/docgen.yml?label=docgen&logo=neovim&logoColor=white&style=for-the-badge)
![Backend](https://img.shields.io/badge/go-backend-lightblue?style=for-the-badge&logo=go&logoColor=white)
![Frontend](https://img.shields.io/badge/lua-frontend-blue?style=for-the-badge&logo=lua&logoColor=white)

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/yellow_img.png)](https://www.buymeacoffee.com/kndndrj)

<!-- DOCGEN_IGNORE_END -->

# Neovim DBee

**Database Client for NeoVim!**

**Execute Your Favourite Queries From the Comfort of Your Editor!**

**Backend in Go!**

**Frontend in Lua!**

**Doesn't rely on CLI tools!**

**Get Results FAST With Under-the-hood Iterator!**

**Bees Love It!**

***Alpha Software - Expect Breaking Changes!***

<!-- DOCGEN_IGNORE_START -->

![Screenshot](assets/screenshot.jpg)

<!-- DOCGEN_IGNORE_END -->

<!-- DOCGEN_IGNORE_START -->

### Video Introduction

If you prefer to watch a video than to browse through docs, I made a video, which you can watch
[here](https://youtu.be/MDlYsGbKJyQ)

<!-- DOCGEN_IGNORE_END -->

## Installation

**requires nvim>=0.10 and Go>=1.27**

For this fork, build from source with `install("go")`. The inherited download manifest points
to upstream binaries, which do not include this fork's changes. The default native build also
requires a C/C++ toolchain; disable CGO to omit DuckDB if needed.

- packer.nvim:

  ```lua
  use {
    "Metrol/nvim-dbee",
    branch = "pincolumns",
    requires = {
      "MunifTanjim/nui.nvim",
    },
    run = function()
      -- Build this fork; upstream release binaries lack its changes.
      require("dbee").install("go")
    end,
    config = function()
      require("dbee").setup(--[[optional config]])
    end
  }
  ```

- lazy.nvim:

  ```lua
  {
    "Metrol/nvim-dbee",
    branch = "pincolumns",
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
    build = function()
      -- Build this fork; upstream release binaries lack its changes.
      require("dbee").install("go")
    end,
    config = function()
      require("dbee").setup(--[[optional config]])
    end,
  },
  ```

### Platform Support

<!-- DOCGEN_IGNORE_START -->

<details>
  <summary>Click to expand</summary>
<!-- DOCGEN_IGNORE_END -->

This project aims to be as cross-platform as possible, but there are some limitations (for example
some of the go dependencies only work on certain platforms). To address this issue, the client
implementations are detached from the main logic and they register themselves to dbee backend on
plugin start. This allows the use of build constraints, which we use to exclued certain client
implementations on certain platforms.

The CI pipeline tries building the binary for GOARCH/GOOS combinations specified in
[targets.json](ci/targets.json) - if the builds succeed, they are stored in a
[remote bucket](https://github.com/kndndrj/nvim-dbee-bucket) on a separate branch per run.
Additionally, the [install manifest](lua/dbee/install/__manifest.lua) gets created.

To increase cgo cross-platform support, the pipeline uses zig as a C compiler.

To check if your platform is currently supported, check out the mentioned manifest and the targets
file.

<!-- DOCGEN_IGNORE_START -->

</details>
<!-- DOCGEN_IGNORE_END -->

### Manual Binary Installation

<!-- DOCGEN_IGNORE_START -->

<details>
  <summary>Click to expand</summary>
<!-- DOCGEN_IGNORE_END -->

The installation examples include the `build`/`run` functions, which get triggered once the plugin
updates. This should be sufficient for the majority of users. If that doesn't include you, then you
have a few options:

- just install with the `"go"` option (this performs `go build` under the hood):
  ```lua
  require("dbee").install("go")
  ```
- Download an already compiled binary from one of urls in the
  [install manifest](lua/dbee/install/__manifest.lua)
- `go install` (the install location will vary depending on your local go configuration):
  ```sh
  # This command installs upstream DBee, not this fork:
  go install github.com/kndndrj/nvim-dbee/dbee@<version>
  ```
- Clone and build
  ```sh
  # Clone the repository and cd into the "go subfolder"
  git clone <this_repo>
  cd <this_repo>/dbee
  # Build the binary (optional output path)
  go build [-o ~/.local/share/nvim/dbee/bin/dbee]
  ```

<!-- DOCGEN_IGNORE_START -->

</details>
<!-- DOCGEN_IGNORE_END -->

## Configuration

You can pass an optional table parameter to `setup()` function.

Here are the defaults:

<!--DOCGEN_CONFIG_START-->

<!-- Contents from lua/dbee/config.lua are inserted between these tags for docgen. -->

[`config.lua`](lua/dbee/config.lua)

<!--DOCGEN_CONFIG_END-->

## Usage

Call the `setup()` function with an optional config parameter.

<!-- DOCGEN_IGNORE_START -->

<details>
  <summary>Brief reference (click to expand):</summary>
<!-- DOCGEN_IGNORE_END -->

```lua
-- Open/close/toggle the UI.
require("dbee").open()
require("dbee").close()
require("dbee").toggle()
-- Run a query on the currently active connection.
require("dbee").execute(query)
-- Store the current result to file/buffer/yank-register (see "Getting Started").
require("dbee").store(format, output, opts)
```

The same functions are also available through the `:Dbee` user command.

<!-- DOCGEN_IGNORE_START -->

</details>
<!-- DOCGEN_IGNORE_END -->

### Getting Started

Here are a few steps to quickly get started:

- call the `setup()` function in your `init.lua`

- Specify connections using one or more sources (reffer to [this section](#specifying-connections)).

- When you restart the editor, call `lua require("dbee").open()` to open the UI.

- Navigate to the drawer (tree) and use the following key-bindings to perform different actions
  depending on the context (the mappings can all be changed in the config):

  - All nodes:

    - Press `o` to toggle the tree node.
    - Press `r` to manually refresh the tree.

  - Connections:

    - Press `cw` to edit the connection
    - Press `dd` to delete it (if source supports saving, it's also removed from there - see more
      below.)
    - Press `<CR>` to perform an action - view history or look at helper queries. Pressing `<CR>`
      directly on the connection node will set it as the active one

  - Scratchpads:

    - Press `<CR>` on the `new` node to create a new scratchpad.
    - When you try to save it to disk (`:w`), the path is automatically filled for you. You can
      change the name to anything you want, if you save it to the suggested directory, it will load
      the next time you open DBee.
    - Press `cw` to rename the scratchpad.
    - Press `dd` to delete it (also from disk).
    - Pressing `<CR>` on an existing scratchpad in the drawer will open it in the editor pane.

  - Help:

    - Just view the key bindings.

- Once you selected the connection and created a scratchpad, you can navigate to the editor pane
  (top-right by default) and start writing queries. In editor pane, you can use the following
  actions:

  - Highlight some text in visual mode and press `BB` - this will run the selected query on the
    active connection.
  - If you press `BB` in normal mode, you run the whole scratchpad on the active connection.

- If the request was successful, the results should appear in the "result" buffer (bottom right by
  default). If the total number of results was lower than the `page_size` parameter in config (100
  by default), all results should already be present. If there are more than `page_size` results,
  you can "page" through them using one of the following:

| Navigation using lua script <br/> (even if your cursor is outside the result buffer) |       Description       | Default key mapping <br/> (cursor should be inside result buffer) |
| ------------------------------------------------------------------------------------ | :---------------------: | :---------------------------------------------------------------: |
| `require("dbee").api.ui.result_page_next()`                                          |     Go to next page     |                                 L                                 |
| `require("dbee").api.ui.result_page_prev()`                                          | Go to the previous page |                                 H                                 |
| `require("dbee").api.ui.result_page_last()`                                          |   Go to the last page   |                                 E                                 |
| `require("dbee").api.ui.result_page_first()`                                         |  Go to the first page   |                                 F                                 |

- Once in the "result" buffer, you can yank the results with the following keys:

  - `yaj` yank current row as json (or row range in visual mode)
  - `yac` yank current row as CSV (or row range in visual mode)
  - `yaJ` to yank all rows as json
  - `yaC` to yank all rows as CSV

- The current result (of the active connection) can also be saved to a file, yank-register or buffer
  using `require("dbee").store()` lua function or `:Dbee store` Ex command. Here are some examples:

  ```lua
  -- All rows as CSV to current buffer:
  require("dbee").store("csv", "buffer", { extra_arg = 0 })
  -- Results from row 2 to row 7 as json to file (index is zero based):
  require("dbee").store("json", "file", { from = 2, to = 7, extra_arg = "path/to/file.json"  })
  -- Yank the first row as table
  require("dbee").store("table", "yank", { from = 0, to = 1 })
  -- Yank the last 2 rows as CSV
  -- (negative indices are interpreted as length+1+index - same as nvim_buf_get_lines())
  -- Be aware that using negative indices requires for the
  -- iterator of the result to be drained completely, which might affect large result sets.
  require("dbee").store("csv", "yank", { from = -3, to = -1 })
  ```

- Once you are done or you want to go back to where you were, you can call
  `require("dbee").close()`.

### Working with Project SQL Files

The editor can display an existing SQL buffer alongside the schema browser and results, using the
original buffer and project path:

```lua
local dbee = require("dbee")
local buffer = vim.api.nvim_get_current_buf()
local connection = dbee.api.core.get_current_connection()
assert(connection, "Select a DBee connection first")
dbee.api.ui.editor_attach_buffer(buffer, connection.id)
dbee.open()
```

Attached files appear as `[file] path/to/query.sql` under the connection's local notes. They keep their
unsaved edits and buffer options; `:write` saves the original project file. `BB` runs the buffer or
visual selection, and normal-mode Enter runs the statement under the cursor. Selecting an attached
file restores its assigned connection. Closing DBee restores the previous project window layout.

Attached entries last for the editor session. The drawer's delete action only detaches them, and its
rename action is disabled for project files. Detaching restores prior buffer mappings. Project files
are never copied into DBee's scratchpad directory or deleted by DBee.

### PostgreSQL Named Parameters

Write the same named SQL you use in PHP:

```sql
SELECT r.* FROM "RFP" AS r WHERE r."eventID" = :eventID;
```

Running the query opens one form showing every distinct parameter. Enter raw values without SQL quotes;
PostgreSQL infers their types from the query. Use explicit casts such as `:value::text` where needed.
Tab or Enter moves to the next field; Shift-Tab moves back. Every focused field starts in Insert
mode. Ctrl-N toggles SQL NULL for the current field, shown as `[NULL]` beside its name; an empty
value without that flag is an empty string. Ctrl-Enter or Ctrl-S runs the query with all values.
Escape cancels the entire run without executing SQL. Fields accept single-line input.

Every run prompts again, prefilled with values remembered for that buffer and connection during the
current Neovim session. Repeated names share one value and prompt. Values are not written into the
SQL buffer or saved in DBee's query history.

The Go backend converts named markers to PostgreSQL `$1`, `$2`, etc. and sends values separately
through the driver's native binding API. It skips quoted text, dollar quotes, comments and `::`
casts. Named and positional markers cannot be mixed in one bound query. Binding is currently
PostgreSQL-only; other database drivers continue to support queries without parameters.

Parameterized execution accepts one statement at a time. Select the desired statement or use
normal-mode Enter in DBee's editor pane. Files without parameters retain their existing batch
behavior. Native `BB`, Enter, `:Dbee execute`, Lua `execute()`, and the configured project-buffer run
shortcut all use the same prompting path.

The low-level `api.core.connection_execute()` remains an unprompted raw execution API. Use
`api.core.connection_run(id, query, bufnr, callback)` for prompts, or
`api.core.connection_execute_bound(id, query, values)` to supply values directly. Each value is a
table with `text` and `is_null` fields; bound calls retain the original named SQL in history.

### Navigating Result Columns

In the results pane, normal-mode Left and Right jump to the previous or next data column on the
current row. Counts such as `3<Right>` jump several columns. The window scrolls horizontally as needed,
and movement stops at the first or last column. `h`/`l` and Visual-mode arrows keep their usual text
selection behavior for copying values. These mappings can be customized through `result.mappings`
using the `column_prev` and `column_next` actions.

### Specifying Connections

Connection represents an instance of the database client (i.e. one database). This is how it looks
like:

```lua
{
  id = "optional_identifier" -- only mandatory if you edit a file by hand. IT'S YOUR JOB TO KEEP THESE UNIQUE!
  name = "My Database",
  type = "sqlite", -- type of database driver
  url = "~/path/to/mydb.db",
}
```

The connections are loaded to dbee using so-called "sources". They can be added to dbee using the
`setup()` function:

```lua
  require("dbee").setup {
    sources = {
      require("dbee.sources").MemorySource:new({
        {
          name = "...",
          type = "...",
          url = "...",
        },
        -- ...
      }),
      require("dbee.sources").EnvSource:new("DBEE_CONNECTIONS"),
      require("dbee.sources").FileSource:new(vim.fn.stdpath("cache") .. "/dbee/persistence.json"),
    },
    -- ...
  },
```

The above sources are just built-ins. Here is a short description of them:

- `MemorySource` just loads the connections you give it as an argument.

- `EnvSource` loads connection from an environment variable Just export the variable you gave to the
  loader and you are good to go:

  ```sh
    export DBEE_CONNECTIONS='[
        {
            "name": "DB from env",
            "url": "username:password@tcp(host)/database-name",
            "type": "mysql"
        }
    ]'
  ```

- `FileSource` loads connections from a given json file. It also supports editing and adding
  connections interactively

If the source supports saving and editing you can add connections manually using the "add" item in
the drawer. Fill in the values and write the buffer (`:w`) to save the connection. By default, this
will save the connection to the global connections file and will persist over restarts (because
default `FileSource` supports saving)

Another option is to use "edit" item in the tree and just edit the source manually.

If you aren't satisfied with the default capabilities, you can implement your own source. You just
need to fill the `Source` interface and pass it to config at setup (`:h dbee.sources`).

#### Secrets

If you don't want to have secrets laying around your disk in plain text, you can use the special
placeholders in connection strings (this works using any method for specifying connections).

Each connection parameter is passed through go templating engine, which has two available functions:

- `env` for retrieving environment variables and
- `exec` for evaluating shell commands.

The template syntax for functions is the following: `{{ <func> "<param>" }}`. If you are dealing
with json, you need to escape double quotes, so it's sometimes better to use backticks instead
(`` {{ <func> `<param>` }} ``).

Example:

Using the `DBEE_CONNECTIONS` environment variable for specifying connections and exporting secrets
to environment:

```sh
# Define connections
export DBEE_CONNECTIONS='[
    {
        "name": "{{ exec `echo Hidden Database` }}",
        "url": "postgres://{{ env \"SECRET_DB_USER\" }}:{{ env `SECRET_DB_PASS` }}@localhost:5432/{{ env `SECRET_DB_NAME` }}?sslmode=disable",
        "type": "postgres"
    }
]'

# Export secrets
export SECRET_DB_NAME="secretdb"
export SECRET_DB_USER="secretuser"
export SECRET_DB_PASS="secretpass"
```

If you start neovim in the same shell, this will evaluate to the following connection:

```lua
{ {
  name = "Hidden Database",
  url = "postgres://secretuser:secretpass@localhost:5432/secretdb?sslmode=disable",
  type = "postgres",
} }
```

## API

Dbee comes with it's own API interface. It is split into two parts:

- core (interacting with core of the plugin),
- ui (interacting with ui of the plugin).

You can access it like this:

```lua
require("dbee").api.core.some_func()
require("dbee").api.ui.some_func()
```

## Extensions

- [`nvim-projector`](https://github.com/kndndrj/nvim-projector) To use dbee with projector, use
  [this extension](https://github.com/kndndrj/projector-dbee).

- [`nvim-cmp`](https://github.com/hrsh7th/nvim-cmp) [Here](https://github.com/MattiasMTS/cmp-dbee),
  a completion plugin with dbee support.

<!-- DOCGEN_IGNORE_START -->

## Pinned result headers

Column names stay visible while scrolling down through tabular results. The pinned header
follows horizontal scrolling and column jumps, while result text and copying remain unchanged.
It disappears when the original header is visible, and clears on new queries, errors, or closing
the results pane. Disable it with `result = { pin_headers = false }` in `setup()`.

## Development

Building this fork requires Go 1.27 or newer. Its BigQuery client is pinned to v1.85.0.
Build the backend from this checkout rather than downloading an upstream release binary.

```sh
cd dbee
go build -o ~/.local/share/nvim/dbee/bin/dbee .
```

The default build includes DuckDB on supported platforms and requires a C/C++ toolchain.
Set `CGO_ENABLED=0` to omit DuckDB when only pure-Go drivers are needed.

Run the project-buffer regression checks from the repository root:

```sh
nvim --headless -u NONE -i NONE -l tests/editor_buffers.lua
nvim --headless -u NONE -i NONE -l tests/result_columns.lua
nvim --headless -u NONE -i NONE -l tests/result_headers.lua
nvim --headless -u NONE -i NONE -l tests/result_header_events.lua
nvim --headless -u NONE -i NONE -l tests/parameters.lua
nvim --headless -u NONE -i NONE -l tests/parameter_prompt.lua
```

The checks use temporary SQL files and a fake execution handler; no database server is needed.
They require `nui.nvim`, using its lazy.nvim installation by default. Set `NUI_NVIM_PATH` to use a
different installation. The Go backend does not need rebuilding for Lua-only changes. Native binding adds RPC endpoints,
so rebuild and restart Neovim after updating it. Backend tests include `go test ./core/... ./handler/...`
and the PostgreSQL binding tests in `./adapters` (use `CGO_ENABLED=0` to exclude DuckDB when needed).

With this fork loaded in your Neovim configuration and a PostgreSQL connection available, run the
read-only binding integration check against constant values:

```sh
DBEE_POSTGRES_TEST_URL='postgresql://user@host/database' nvim --headless -i NONE '+luafile tests/postgres_parameters.lua'
```

This check can use `.pgpass` and does not read application tables or modify database data.

Reffer to [ARCHITECTURE.md](ARCHITECTURE.md) for a brief overview of the architecture.

## Contributing

Contributions are more than welcome!

Do so by creating an `issue` or a `PR`.

You are also welcome to join the [#nvim-dbee:matrix.org](https://matrix.to/#/#nvim-dbee:matrix.org)
chat for more direct communication.

<!-- DOCGEN_IGNORE_END -->
