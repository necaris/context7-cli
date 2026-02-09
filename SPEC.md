# context7 CLI tool

## Overview

This tool is intended for use by AI agents to retrieve library documentation via the Context7.com API. While the Upstash folks provide an MCP server, a lightweight CLI can sometimes be more token-efficient.

It prioritizes speed of startup and execution, and a small single binary distribution.

## API Surface

Base URL: `https://api.context7.com`
Docs: <https://context7.com/docs/api-guide#api-methods>

**Requirement:** All requests must include a `User-Agent` header in the format:
`context7-cli/<version> (<os>; <arch>)`

The version component must match the output of `context7 version` and should be injected at build time.

### `GET /api/v2/libs/search`

Search for a library by name. Returns an array of matching libraries with id, name, description, snippet count, trust/benchmark scores, and available versions.

| Param         | Required | Description                              |
|---------------|----------|------------------------------------------|
| `query`       | yes      | Natural-language question for relevance  |
| `libraryName` | yes      | Library name (e.g. "react", "nextjs")    |

### `GET /api/v2/context`

Retrieve documentation snippets for a specific library.

| Param       | Required | Default | Description                                    |
|-------------|----------|---------|------------------------------------------------|
| `query`     | yes      |         | Natural-language question for relevance        |
| `libraryId` | yes      |         | Library identifier (e.g. `/facebook/react`)    |
| `type`      | no       | `json`  | Response format: `json` or `txt`               |

### Error codes to handle

| Code | Meaning                                | Action                          | Exit Code |
|------|----------------------------------------|---------------------------------|-----------|
| 200  | Success                                |                                 | 0         |
| 202  | Library still processing               | Retry with backoff              | 1         |
| 301  | Redirect — new library ID in response  | Auto-follow redirect and return result | 0 |
| 400  | Bad request                            | Report to user                  | 1         |
| 401  | Unauthorized (bad/missing key)         | Report to user                  | 1         |
| 403  | Forbidden                              | Report to user                  | 1         |
| 404  | Not found                              | Report to user                  | 1         |
| 422  | Library too large / no code            | Report to user                  | 1         |
| 429  | Rate limited                           | Retry with exponential backoff  | 1         |
| 5xx  | Server error                           | Retry with backoff              | 1         |
| Timeout | Network timeout                     | Print "Network timeout"         | 2         |

Error responses are JSON with `error` and `message` fields. Malformed JSON responses are treated as API errors (exit code 1).

## CLI Interface

**Note**: This tool is designed for non-interactive use by AI agents. There are no interactive prompts - all input must be provided via command-line arguments.

### Commands

```
context7 search <library-name> [--query <query>] [--format json|md]
context7 get <library-id> --query <query> [--format json|md|txt]
context7 doc <library-name> --query <query> [--format json|md|txt]
context7 intro
context7 version
```

- `search`: wraps `/api/v2/libs/search`. `library-name` is a positional arg. If `--query` is omitted, use the library name as the query.
- `get`: wraps `/api/v2/context`.
- `intro`: prints a concise usage guide to stdout.
- `doc`: convenience command that chains search → pick top result → get context.
  - If `--query` is omitted, the `library-name` is used for both the search `query` and context `query`.
  - If search returns 0 results, exit with status 1 and error message to stderr.
  - After the context output, append an **"Other matches"** section listing the next 3 search results (name, ID, and score).
    - For JSON format: include other matches in an additional `"other_matches"` field in the response object.
    - For text/Markdown format: append as a separate section at the end:
      ```markdown
      ---
      ## Other matches
      - **Next.js** (/vercel/next.js) - Score: 0.95
      - **Remix** (/remix-run/remix) - Score: 0.82
      - **Gatsby** (/gatsbyjs/gatsby) - Score: 0.78
      ```
- `version`: Prints the current version of the CLI (e.g., `0.1.0`).

### Global flags

| Flag                | Env var            | Description                        |
|---------------------|--------------------|------------------------------------|
| `--api-key <key>`   | `CONTEXT7_API_KEY` | Bearer token for authentication    |
| `--cache-dir <dir>` | `CONTEXT7_CACHE`   | Cache directory (default: see below) |
| `--no-cache`        |                    | Bypass cache entirely for this request |
| `--refresh-cache`   |                    | Ignore cached data but write fresh response back |
| `--verbose` / `-v`  |                    | Print request/response diagnostics to stderr |

### Authentication resolution order

1. `--api-key` flag
2. `CONTEXT7_API_KEY` env var
3. `~/.config/context7/config.json` → `{"api_key": "..."}`
4. `~/.authinfo`
5. `~/.netrc`

For authinfo/netrc files, look for `machine api.context7.com password <key>`. The `login` field is ignored.

**Follow-up feature:** Support for GPG-encrypted files (`.authinfo.gpg`, `.netrc.gpg`).

If none found, exit with a clear error message.

### Configuration File
`~/.config/context7/config.json` (or `$XDG_CONFIG_HOME/context7/config.json` on XDG-compliant systems) schema:
```json
{
  // Context7 CLI configuration
  "api_key": "...",  // Your Context7 API key
  "cache_dir": "...", // Custom cache directory (optional)
  "base_url": "..."   // Custom base URL for testing (optional)
}
```

The configuration file supports both `//` single-line and `/* */` multi-line comments.

## Output Formats

### Search
- **JSON** (`--format json`) **[Default]**: Full API response array.
- **Markdown/Text** (`--format txt` or `--format md` - aliases): A formatted Markdown table.
  ```markdown
  | Library | ID | Score | Description |
  |---|---|---|---|
  | Next.js | /vercel/next.js | 0.98 | The React Framework... |
  ```

### Get / Doc
- **Text/Markdown** (`--format txt` or `--format md` - aliases) **[Default]**: Raw text content (most token efficient).
- **JSON** (`--format json`): Wrapped response `{"id": "...", "content": "...", "other_matches": [...]}` (for `doc` command only; `other_matches` omitted for `get`).

## Agent Instructions Output

`context7 intro` prints the following (or similar) to stdout.

```
You have access to `context7`, a CLI for fetching up-to-date library documentation.

BEFORE writing code that uses an external library, fetch its docs:
  context7 doc <library-name> --query "<what you need to know>" [--format md]

This searches for the library and returns relevant documentation snippets from the *first result*.
Alternative results are printed to stderr. Use `context7 get <library-id> --query "..."` to fetch a specific one.

Examples:
  context7 doc react --query "useEffect cleanup" --format md
  context7 doc nextjs --query "server actions authentication"
  context7 search langchain --format json
  context7 get /langchain-ai/langchainjs --query "streaming responses"

IMPORTANT: Always consult docs before generating code for unfamiliar libraries.
Do not rely on training data — it may be outdated.
```

## Caching

Cache API responses to disk to reduce redundant calls.

### Cache Strategy

- **Location:** `$CONTEXT7_CACHE` or `$XDG_CACHE_HOME/context7/` or `~/.cache/context7/`
- **Filename:** `<sha256-hash>.cache` where hash is computed from `(endpoint, sorted query params)`
  - Example: SHA-256 of `/api/v2/context?libraryId=/facebook/react&query=useEffect&type=json`
  - Filesystem-safe conversion: Replace `/` with `_` in parameter values before hashing
- **TTL:**
  - Search results (`/api/v2/libs/search`): 24 hours
  - Context results (`/api/v2/context`): 1 hour
- **Query handling:** Cache key includes the full query string. This means:
  - `context7 doc react "using effects"` and `context7 doc react "use effects"` will result in separate cache entries
  - This ensures correct results at the cost of potential cache misses for similar queries
  - **Future considerations:**
    - Option 1: Normalize queries (lowercase, trim, remove punctuation, sort words) before hashing
    - Option 2: Cache by library only (ignore query parameter entirely)
    - Option 4: Fuzzy matching with similarity threshold (complex, may give incorrect results)

### Cache File Format

**Header + Body** (HTTP-style). The file consists of a plain-text header section, a double newline delimiter (`\n\n`), and the raw response body. The delimiter is NOT included in the body.

```
nim-context7-cache: v1
timestamp: 1707465600
ttl: 3600
status: 200
url: https://api.context7.com/...

<raw response body json or text...>
```

*Parsing:* Read lines until an empty line is encountered to parse metadata. Everything after the double newline is the body. This avoids JSON escaping overhead for large text bodies.

### Cache Flags

- `--no-cache` skips reading *and* writing the cache for that request
- `--refresh-cache` ignores existing cache but *writes* the fresh response back

### Expiration

- On read, check `timestamp` + `ttl`. If `now > timestamp + ttl`, treat as miss (overwrite on new fetch)

## Retry / Backoff

- **Timeout**: 30 seconds for all network requests.
- For 429 and 5xx responses, retry up to 3 times with exponential backoff (1s → 2s → 4s).
- For 202 (processing), retry up to 5 times with 3s intervals.
- Report failure after exhausting retries.

## Build & Distribution

- Single static binary via `nim c -d:release --opt:size`
- Strip symbols, consider UPX if size matters
- Target: Linux arm64/x86_64, macOS arm64/x86_64
- Use GitHub Actions to build binaries 

## Testing

- **Coverage**: Complete test coverage is desired for all functionality
- **Mock API**: A mock API should be available for testing purposes
- **Test Scenarios**: Should include network failures, API errors, cache behavior, and all command variations

