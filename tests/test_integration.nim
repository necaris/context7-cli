## Integration tests for the full CLI flow
##
## Tests the complete pipeline: CLI commands -> HTTP client (mocked) -> JSON parsing -> Markdown formatting
## Uses fixture data to mock API responses at the HTTP layer.

import std/[unittest, json, strutils, tables, os, osproc, tempfiles]
import ../src/types
import ../src/http_client
import ../src/commands
import fixtures

# =============================================================================
# Helper to capture stdout
# =============================================================================

template captureStdout(body: untyped): string =
  let (tmpFile, tmpPath) = createTempFile("stdout_", ".txt")
  let oldStdout = stdout
  stdout = tmpFile
  try:
    body
  finally:
    stdout = oldStdout
    tmpFile.close()
  readFile(tmpPath)

# =============================================================================
# Mock HTTP Fetcher
# =============================================================================

type
  MockRoute = object
    urlPattern: string
    status: int
    body: string

var mockRoutes {.threadvar.}: seq[MockRoute]
var lastRequestUrl {.threadvar.}: string
var lastRequestHeaders {.threadvar.}: seq[(string, string)]

proc clearMocks() =
  mockRoutes = @[]
  lastRequestUrl = ""
  lastRequestHeaders = @[]

proc addMockRoute(urlPattern: string, status: int, body: string) =
  mockRoutes.add(MockRoute(urlPattern: urlPattern, status: status, body: body))

proc mockHttpFetcher(url: string, headers: seq[(string, string)]): HttpResponse =
  {.cast(gcsafe).}:
    lastRequestUrl = url
    lastRequestHeaders = headers

    for route in mockRoutes:
      if route.urlPattern in url:
        return HttpResponse(status: route.status, body: route.body)

    # Default 404 if no route matches
    return HttpResponse(status: 404, body: """{"error": "not_found", "message": "No mock route matched"}""")

proc setupMockHttp() =
  httpFetchImpl = mockHttpFetcher

proc teardownMockHttp() =
  httpFetchImpl = nil
  clearMocks()

# =============================================================================
# Test Suites
# =============================================================================

suite "Search Command Integration":
  setup:
    setupMockHttp()
    clearMocks()

  teardown:
    teardownMockHttp()

  test "search returns markdown table":
    addMockRoute("/api/v2/libs/search", 200, SearchResponseJson)

    let output = captureStdout:
      search("react", "ui library", fmtMarkdown, "test-api-key", verbose = false, noCache = true, refreshCache = false)

    # Verify markdown table structure
    check "| Library | ID | Score | Description |" in output
    check "|---|---|---|---|" in output
    check "| React |" in output
    check "| /facebook/react |" in output
    check "| 88.0 |" in output
    check "| Next.js |" in output
    check "| React Router |" in output

  test "search returns raw JSON":
    addMockRoute("/api/v2/libs/search", 200, SearchResponseJson)

    let output = captureStdout:
      search("react", "ui library", fmtJson, "test-api-key", verbose = false, noCache = true, refreshCache = false)

    # Should be valid JSON
    let parsed = parseJson(output)
    check parsed.kind == JArray
    check parsed.len == 3
    check parsed[0]["title"].getStr() == "React"

  test "search truncates long descriptions in markdown":
    addMockRoute("/api/v2/libs/search", 200, LongDescriptionResponse)

    let output = captureStdout:
      search("longdesc", "find libraries", fmtMarkdown, "test-api-key", verbose = false, noCache = true, refreshCache = false)

    # Description should be truncated
    check "..." in output
    # Full description should NOT appear
    check "should be truncated in the markdown table output" notin output

  test "search with empty results":
    addMockRoute("/api/v2/libs/search", 200, EmptySearchResponse)

    let output = captureStdout:
      search("nonexistent", "nothing here", fmtMarkdown, "test-api-key", verbose = false, noCache = true, refreshCache = false)

    # Should still have headers but no data rows
    check "| Library | ID | Score | Description |" in output
    let lines = output.strip().splitLines()
    check lines.len == 2  # header + separator only

  test "search sends correct API key header":
    addMockRoute("/api/v2/libs/search", 200, SearchResponseJson)

    discard captureStdout:
      search("react", "ui library", fmtJson, "my-secret-key", verbose = false, noCache = true, refreshCache = false)

    # Verify Authorization header was sent
    var foundAuth = false
    {.cast(gcsafe).}:
      for (key, value) in lastRequestHeaders:
        if key == "Authorization":
          check value == "Bearer my-secret-key"
          foundAuth = true
          break
    check foundAuth

  test "search URL contains correct query params":
    addMockRoute("/api/v2/libs/search", 200, SearchResponseJson)

    discard captureStdout:
      search("react", "hooks tutorial", fmtJson, "test-key", verbose = false, noCache = true, refreshCache = false)

    # URL should contain encoded query
    {.cast(gcsafe).}:
      check "query=" in lastRequestUrl
      check "libraryName=" in lastRequestUrl

suite "Get Context Command Integration":
  setup:
    setupMockHttp()
    clearMocks()

  teardown:
    teardownMockHttp()

  test "get returns markdown content":
    addMockRoute("/api/v2/context", 200, ContextResponseText)

    let output = captureStdout:
      getContext("/facebook/react", "hooks", fmtMarkdown, "test-key", verbose = false, noCache = true, refreshCache = false)

    # Should output the content directly
    check "# React Documentation" in output
    check "## Getting Started" in output
    check "npm install react react-dom" in output

  test "get returns JSON wrapper":
    addMockRoute("/api/v2/context", 200, ContextResponseJson)

    let output = captureStdout:
      getContext("/facebook/react", "hooks", fmtJson, "test-key", verbose = false, noCache = true, refreshCache = false)

    let parsed = parseJson(output)
    check parsed.hasKey("id")
    check parsed.hasKey("content")
    check parsed["id"].getStr() == "/facebook/react"

  test "get URL contains library ID and query":
    addMockRoute("/api/v2/context", 200, ContextResponseJson)

    discard captureStdout:
      getContext("/vercel/next.js", "routing", fmtMarkdown, "test-key", verbose = false, noCache = true, refreshCache = false)

    check "libraryId=" in lastRequestUrl
    check "query=" in lastRequestUrl

suite "Doc Command Integration":
  setup:
    setupMockHttp()
    clearMocks()

  teardown:
    teardownMockHttp()

  test "doc combines search and get in markdown":
    # First call is search, second is get context
    addMockRoute("/api/v2/libs/search", 200, SearchResponseJson)
    addMockRoute("/api/v2/context", 200, ContextResponseJson)

    let output = captureStdout:
      doc("react", "hooks", fmtMarkdown, "test-key", verbose = false, noCache = true, refreshCache = false)

    # Should have documentation content
    check "# React Documentation" in output or "React" in output

    # Should have "Other matches" section
    check "## Other matches" in output
    check "**Next.js**" in output
    check "**React Router**" in output
    check "Score:" in output

  test "doc returns JSON with other_matches":
    addMockRoute("/api/v2/libs/search", 200, SearchResponseJson)
    addMockRoute("/api/v2/context", 200, ContextResponseJson)

    let output = captureStdout:
      doc("react", "hooks", fmtJson, "test-key", verbose = false, noCache = true, refreshCache = false)

    let parsed = parseJson(output)
    check parsed.hasKey("id")
    check parsed.hasKey("content")
    check parsed.hasKey("other_matches")
    check parsed["other_matches"].kind == JArray

  test "doc with single search result has no other matches":
    let singleResult = """[{"id": "/only/one", "title": "OnlyOne", "description": "Single result", "totalSnippets": 50, "trustScore": 95, "benchmarkScore": 99, "versions": ["v1.0.0"]}]"""
    addMockRoute("/api/v2/libs/search", 200, singleResult)
    addMockRoute("/api/v2/context", 200, ContextResponseJson)

    let output = captureStdout:
      doc("onlyone", "docs", fmtMarkdown, "test-key", verbose = false, noCache = true, refreshCache = false)

    # Should NOT have other matches section (or it should be empty)
    let lines = output.splitLines()
    var hasOtherMatchesBullets = false
    for line in lines:
      if line.startsWith("- **") and "Score:" in line:
        hasOtherMatchesBullets = true
        break
    check not hasOtherMatchesBullets

suite "Error Handling Integration":
  setup:
    setupMockHttp()
    clearMocks()

  teardown:
    teardownMockHttp()

  test "API error propagates correctly":
    addMockRoute("/api/v2/libs/search", 404, ErrorResponse)

    expect ApiError:
      discard captureStdout:
        search("nonexistent", "nothing", fmtJson, "test-key", verbose = false, noCache = true, refreshCache = false)

  test "401 unauthorized error":
    addMockRoute("/api/v2/libs/search", 401, """{"error": "unauthorized", "message": "Invalid API key"}""")

    expect ApiError:
      discard captureStdout:
        search("react", "ui", fmtJson, "bad-key", verbose = false, noCache = true, refreshCache = false)

suite "Output Format Consistency":
  setup:
    setupMockHttp()
    clearMocks()

  teardown:
    teardownMockHttp()

  test "markdown table rows have consistent columns":
    addMockRoute("/api/v2/libs/search", 200, SearchResponseJson)

    let output = captureStdout:
      search("react", "ui library", fmtMarkdown, "test-key", verbose = false, noCache = true, refreshCache = false)

    for line in output.strip().splitLines():
      # Each line should have exactly 5 pipes (4 columns)
      check line.count('|') == 5

  test "score displayed as float with 1 decimal":
    addMockRoute("/api/v2/libs/search", 200, SearchResponseJson)

    let output = captureStdout:
      search("react", "ui library", fmtMarkdown, "test-key", verbose = false, noCache = true, refreshCache = false)

    # Check score format patterns (benchmarkScore as float with 1 decimal)
    check "| 88.0 |" in output
    check "| 72.0 |" in output
    check "| 68.0 |" in output

  test "JSON output is valid and parseable":
    addMockRoute("/api/v2/libs/search", 200, SearchResponseJson)

    let output = captureStdout:
      search("react", "ui library", fmtJson, "test-key", verbose = false, noCache = true, refreshCache = false)

    # Should not raise
    let parsed = parseJson(output)
    check parsed.kind == JArray

  test "text format outputs readable content":
    addMockRoute("/api/v2/context", 200, ContextResponseText)

    let output = captureStdout:
      getContext("/facebook/react", "docs", fmtText, "test-key", verbose = false, noCache = true, refreshCache = false)

    # Should have readable text content
    check "React" in output or "Documentation" in output

when isMainModule:
  echo "Running integration tests..."
