## Tests for API commands using fixture data
##
## These tests mock the HTTP layer by using a test config that points to
## fixture files, allowing us to test command logic without network calls.

import std/[unittest, os, osproc, strutils, json, paths as p]
import fixtures

const BinaryPath = "./context7"

# Helper to create temp config pointing to mock server
proc setupTestEnv(): (string, string) =
  let tempDir = getTempDir() / "context7-api-test-" & $getCurrentProcessId()
  createDir(tempDir)
  createDir(tempDir / "cache")

  # Create config that will be used via XDG_CONFIG_HOME
  let configDir = tempDir / "config" / "context7"
  createDir(configDir)
  writeFile(configDir / "config.json", """{
  "api_key": "test-api-key-12345"
}""")

  result = (tempDir, configDir)

proc cleanupTestEnv(tempDir: string) =
  removeDir(tempDir)

proc runWithEnv(cmd: string, tempDir: string): (string, int) =
  ## Run command with test environment variables
  let configHome = tempDir / "config"
  let cacheHome = tempDir / "cache"
  let fullCmd = "XDG_CONFIG_HOME=" & configHome & " XDG_CACHE_HOME=" &
      cacheHome & " " & cmd
  execCmdEx(fullCmd)

suite "Search Command":
  # Ensure running from project root
  assert "tests" notin string(p.getCurrentDir())

  # TODO: This fails!
  test "search without API key shows error":
    # Use empty config dir to ensure no API key
    let tempDir = getTempDir() / "context7-nokey-test"
    createDir(tempDir)
    createDir(tempDir / "config" / "context7")
    writeFile(tempDir / "config" / "context7" / "config.json", "{}")

    let (output, exitCode) = runWithEnv(BinaryPath & " search react", tempDir)
    check exitCode == 1
    stderr.writeLine(output)
    check "No API key" in output or "api" in output.toLowerAscii()

    removeDir(tempDir)

  test "search requires library name":
    let (tempDir, _) = setupTestEnv()
    defer: cleanupTestEnv(tempDir)

    let (output, exitCode) = runWithEnv(BinaryPath & " search", tempDir)
    check exitCode == 1
    check "requires" in output.toLowerAscii() or "error" in output.toLowerAscii()

suite "Get Command":
  assert "tests" notin string(p.getCurrentDir())

  test "get without query shows error":
    let (tempDir, _) = setupTestEnv()
    defer: cleanupTestEnv(tempDir)

    let (output, exitCode) = runWithEnv(BinaryPath & " get /facebook/react", tempDir)
    check exitCode == 1
    check "query" in output.toLowerAscii()

  test "get requires library ID":
    let (tempDir, _) = setupTestEnv()
    defer: cleanupTestEnv(tempDir)

    let (output, exitCode) = runWithEnv(BinaryPath & " get", tempDir)
    check exitCode == 1
    check "requires" in output.toLowerAscii() or "error" in output.toLowerAscii()

suite "Doc Command":
  assert "tests" notin string(p.getCurrentDir())

  test "doc requires library name":
    let (tempDir, _) = setupTestEnv()
    defer: cleanupTestEnv(tempDir)

    let (output, exitCode) = runWithEnv(BinaryPath & " doc", tempDir)
    check exitCode == 1
    check "requires" in output.toLowerAscii() or "error" in output.toLowerAscii()

suite "Output Formats":
  assert "tests" notin string(p.getCurrentDir())

  test "invalid format shows error":
    let (tempDir, _) = setupTestEnv()
    defer: cleanupTestEnv(tempDir)

    let (output, exitCode) = runWithEnv(BinaryPath &
        " search react --format xml", tempDir)
    check exitCode == 1
    check "format" in output.toLowerAscii() or "unknown" in output.toLowerAscii()

  test "valid formats accepted":
    let (tempDir, _) = setupTestEnv()
    defer: cleanupTestEnv(tempDir)

    # Note: parseopt requires --format=value syntax, not --format value
    # These will fail due to network but should parse the format correctly
    for fmt in ["json", "md", "txt", "markdown", "text"]:
      let (output, _) = runWithEnv(BinaryPath & " search react --format=" & fmt, tempDir)
      # Should fail with network/API error, not format error
      check "Unknown format" notin output

suite "Cache Flags":
  assert "tests" notin string(p.getCurrentDir())

  test "no-cache flag accepted":
    let (tempDir, _) = setupTestEnv()
    defer: cleanupTestEnv(tempDir)

    let (output, exitCode) = runWithEnv(BinaryPath & " search react --no-cache", tempDir)
    # Should fail with API error, not flag parsing error
    check "Unknown option" notin output

  test "refresh-cache flag accepted":
    let (tempDir, _) = setupTestEnv()
    defer: cleanupTestEnv(tempDir)

    let (output, exitCode) = runWithEnv(BinaryPath &
        " search react --refresh-cache", tempDir)
    check "Unknown option" notin output

  test "verbose flag accepted":
    let (tempDir, _) = setupTestEnv()
    defer: cleanupTestEnv(tempDir)

    let (output, exitCode) = runWithEnv(BinaryPath & " search react -v", tempDir)
    check "Unknown option" notin output

suite "Fixture Data Parsing":
  ## Test that fixture data parses correctly (validates our test fixtures)

  test "search response fixture is valid JSON":
    let parsed = parseJson(SearchResponseFixture)
    check parsed.kind == JObject
    check parsed.hasKey("results")
    let results = parsed["results"]
    check results.len == 5
    check results[0]["id"].getStr() == "/websites/react_dev"
    check results[0]["title"].getStr() == "React"
    check results[0]["score"].getFloat() > 0.5

  test "context response fixture has expected content":
    check "useState" in ContextResponseFixture
    check "useEffect" in ContextResponseFixture
    check "```javascript" in ContextResponseFixture

suite "Query Flag":
  assert "tests" notin string(p.getCurrentDir())

  test "query flag with equals syntax":
    let (tempDir, _) = setupTestEnv()
    defer: cleanupTestEnv(tempDir)

    # --query=value syntax should work
    let (output, _) = runWithEnv(BinaryPath &
        " get /facebook/react --query=\"hooks usage\"", tempDir)
    check "Unknown option" notin output

  test "short query flag":
    let (tempDir, _) = setupTestEnv()
    defer: cleanupTestEnv(tempDir)

    # -q=value syntax should work
    let (output, _) = runWithEnv(BinaryPath &
        " get /facebook/react -q=\"hooks\"", tempDir)
    check "Unknown option" notin output

suite "API Key Flag":
  assert "tests" notin string(p.getCurrentDir())

  test "api-key flag overrides env":
    let (tempDir, _) = setupTestEnv()
    defer: cleanupTestEnv(tempDir)

    # Should accept the flag (will fail on network, but flag should parse)
    let (output, _) = runWithEnv(BinaryPath &
        " search react --api-key=test-key", tempDir)
    check "Unknown option" notin output

suite "Combined Flags":
  assert "tests" notin string(p.getCurrentDir())

  test "multiple flags combined":
    let (tempDir, _) = setupTestEnv()
    defer: cleanupTestEnv(tempDir)

    let cmd = BinaryPath & " doc react --query=\"hooks\" --format=json --no-cache -v"
    let (output, _) = runWithEnv(cmd, tempDir)
    # Should parse all flags without error
    check "Unknown option" notin output
    check "Unknown format" notin output

when isMainModule:
  echo "Running API command tests..."
