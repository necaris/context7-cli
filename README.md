# context7-cli

A lightweight, fast CLI tool for AI agents to retrieve library documentation via the [Context7.com](https://context7.com) API.

## Features

- 🚀 **Fast startup** - Single 250KB static binary, minimal dependencies
- 💾 **Smart caching** - Disk cache with configurable TTL (24h for searches, 1h for docs)
- 🔐 **Flexible auth** - Multiple auth sources: CLI flags, env vars, config file, .authinfo, .netrc
- 🔄 **Robust networking** - Automatic retries with exponential backoff, 301 redirect following
- 📊 **Multiple formats** - JSON or Markdown/text output for easy parsing
- 🎯 **AI-optimized** - Designed for non-interactive use by AI coding agents

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/yourusername/context7-cli
cd context7-cli

# Build release binary
make build-release

# Optionally install to /usr/local/bin
sudo make install
```

### Pre-built Binaries

Download pre-built binaries for your platform from the [Releases](https://github.com/yourusername/context7-cli/releases) page:

- Linux (x86_64, arm64)
- macOS (arm64, x86_64)

## Quick Start

```bash
# Set your API key
export CONTEXT7_API_KEY="your-api-key"

# Search for a library
context7 search react

# Get documentation for specific queries
context7 doc react --query "useEffect cleanup" --format md

# Get context for a specific library ID
context7 get /facebook/react --query "hooks best practices"
```

## Usage

### Commands

#### `context7 version`
Print the CLI version.

#### `context7 intro`
Show usage guide (designed for AI agents).

#### `context7 search <library-name> [options]`
Search for libraries matching a name.

**Options:**
- `--query <query>` - Search query (defaults to library name)
- `--format <json|md|txt>` - Output format (default: json)

**Example:**
```bash
context7 search react --query "react ui library" --format md
```

#### `context7 get <library-id> --query <query> [options]`
Get documentation context for a specific library.

**Options:**
- `--query <query>` - **Required.** What you want to know
- `--format <json|md|txt>` - Output format (default: txt)

**Example:**
```bash
context7 get /facebook/react --query "useState hook" --format txt
```

#### `context7 doc <library-name> --query <query> [options]`
Convenience command that searches for a library and returns docs from the top result, plus other matches.

**Options:**
- `--query <query>` - What you want to know (defaults to library name)
- `--format <json|md|txt>` - Output format (default: txt)

**Example:**
```bash
context7 doc nextjs --query "server actions authentication"
```

**Output:** Documentation from the top match, followed by a list of other relevant libraries.

### Global Flags

| Flag | Env Var | Description |
|------|---------|-------------|
| `--api-key <key>` | `CONTEXT7_API_KEY` | API key for authentication |
| `--cache-dir <dir>` | `CONTEXT7_CACHE` | Custom cache directory |
| `--no-cache` | - | Skip cache entirely |
| `--refresh-cache` | - | Ignore cached data but write fresh response |
| `--verbose` / `-v` | - | Print request/response diagnostics to stderr |

## Configuration

### API Key

The CLI looks for your API key in this order:

1. `--api-key` flag
2. `CONTEXT7_API_KEY` environment variable
3. `~/.config/context7/config.json`
4. `~/.authinfo` (format: `machine api.context7.com password <key>`)
5. `~/.netrc` (format: `machine api.context7.com password <key>`)

### Config File

Create `~/.config/context7/config.json` (or `$XDG_CONFIG_HOME/context7/config.json`):

```json
{
  // Context7 CLI configuration
  "api_key": "your-api-key-here",
  "cache_dir": "/custom/cache/path",  // optional
  "base_url": "https://custom-api.example.com"  // optional, for testing
}
```

Comments (`//` and `/* */`) are supported in the config file.

### Cache

Responses are cached to disk to reduce API calls:

- **Location:** `$CONTEXT7_CACHE` > `$XDG_CACHE_HOME/context7/` > `~/.cache/context7/`
- **TTL:** Search results = 24 hours, Context results = 1 hour
- **Format:** Simple header + body format for fast parsing

## Output Formats

### Search Command

**JSON** (default):
```json
[
  {
    "id": "/facebook/react",
    "name": "React",
    "description": "A JavaScript library for building user interfaces",
    "score": 0.98
  }
]
```

**Markdown** (`--format md` or `--format txt`):
```
| Library | ID | Score | Description |
|---|---|---|---|
| React | /facebook/react | 0.98 | A JavaScript library... |
```

### Get / Doc Commands

**Text** (default) - Raw documentation text (most token-efficient for AI agents)

**JSON** - Wrapped response:
```json
{
  "id": "/facebook/react",
  "content": "documentation text here...",
  "other_matches": [...]  // only in 'doc' command
}
```

## Error Handling

The CLI handles various error conditions gracefully:

- **401/403** - Authentication errors (check your API key)
- **404** - Library not found
- **429** - Rate limiting (automatic retry with backoff)
- **202** - Library still processing (automatic retry up to 5 times)
- **301** - Redirect (automatically follows and returns result)
- **5xx** - Server errors (automatic retry up to 3 times)
- **Timeout** - Network timeout after 30 seconds (exits with code 2)

## For AI Agents

This tool is specifically designed for use by AI coding assistants:

- **Non-interactive** - All input via command-line arguments
- **Token-efficient** - Minimal output, text format by default
- **Reliable** - Automatic retries, caching, clear error messages
- **Fast** - Sub-second startup, small binary size

### Agent Instructions

Run `context7 intro` to get instructions formatted for AI agents:

```bash
context7 intro
```

### Best Practices

1. **Always fetch docs before using a library** - Don't rely on training data
2. **Use the `doc` command** for quick lookups - It searches and fetches in one step
3. **Use `--format txt`** for AI consumption - Most token-efficient
4. **Use `--verbose`** when debugging - Shows HTTP requests/responses

## Development

### Building

```bash
# Debug build
make build

# Release build (optimized, stripped)
make build-release

# Run tests
make test

# Clean build artifacts
make clean
```

### Requirements

- Nim 2.0.0 or later

### Testing

```bash
# Run test suite
nim c -r tests/test_basic.nim

# Run with mock API server
nim c -r tests/mock_api.nim  # In one terminal
# Run integration tests in another terminal
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Contributions welcome! Please:

1. Follow the existing code style
2. Add tests for new features
3. Update documentation as needed
4. Ensure all tests pass before submitting PR

## Links

- [Context7 API Documentation](https://context7.com/docs/api-guide)
- [Context7 Website](https://context7.com)
- [Issue Tracker](https://github.com/yourusername/context7-cli/issues)
