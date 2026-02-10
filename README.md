# context7-cli

CLI tool for AI agents to retrieve library documentation via the [Context7](https://context7.com) API. Written in Nim — single static binary, fast startup, disk caching.

## Installation

### From source

```bash
git clone https://github.com/yourusername/context7-cli
cd context7-cli
make build-release
sudo make install  # optional, installs to /usr/local/bin
```

### Pre-built binaries

Download from the [Releases](https://github.com/yourusername/context7-cli/releases) page (Linux x86_64/arm64, macOS x86_64/arm64).

## Quick start

```bash
export CONTEXT7_API_KEY="your-api-key"

context7 search react
context7 doc react --query "useEffect cleanup"
context7 get /facebook/react --query "hooks best practices"
```

## Commands

| Command | Description |
|---------|-------------|
| `context7 version` | Print CLI version |
| `context7 intro` | Show usage guide (for AI agents) |
| `context7 search <name>` | Search for libraries |
| `context7 get <id> --query <q>` | Get docs for a specific library ID |
| `context7 doc <name> --query <q>` | Search + fetch docs in one step |

### Global flags

| Flag | Env var | Description |
|------|---------|-------------|
| `--api-key <key>` | `CONTEXT7_API_KEY` | API key |
| `--cache-dir <dir>` | `CONTEXT7_CACHE` | Custom cache directory |
| `--no-cache` | — | Skip cache |
| `--refresh-cache` | — | Ignore cached data, write fresh |
| `--verbose` / `-v` | — | Diagnostics to stderr |
| `--format <json\|md\|txt>` | — | Output format |

## Configuration

### API key lookup order

1. `--api-key` flag
2. `CONTEXT7_API_KEY` env var
3. `~/.config/context7/config.json`
4. `~/.authinfo` (`machine api.context7.com password <key>`)
5. `~/.netrc` (`machine api.context7.com password <key>`)

### Config file

`~/.config/context7/config.json` (or `$XDG_CONFIG_HOME/context7/config.json`):

```json
{
  "api_key": "your-api-key-here",
  "cache_dir": "/custom/cache/path",
  "base_url": "https://custom-api.example.com",
  "search_ttl": 21600,
  "context_ttl": 86400
}
```

Comments (`//` and `/* */`) are supported.

### Cache

Responses are cached to disk (`$CONTEXT7_CACHE` > `$XDG_CACHE_HOME/context7/` > `~/.cache/context7/`). Search results expire after 6 hours, context results after 24 hours. Override via config file (`search_ttl` / `context_ttl` keys, in seconds) or env vars (`CONTEXT7_SEARCH_TTL` / `CONTEXT7_CONTEXT_TTL`). Env vars take priority over config file.

## Development

Requires Nim ≥ 2.0.0.

```bash
make build           # debug build
make build-release   # optimized + stripped
make test            # run tests
make clean           # remove build artifacts
```

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).

## Links

- [Context7 API docs](https://context7.com/docs/api-guide)
- [Context7 website](https://context7.com)
- [Issue tracker](https://github.com/yourusername/context7-cli/issues)
