## Basic functionality tests

import std/[unittest, os, osproc, strutils, json, paths as p]

const BinaryPath = "./context7"

suite "Basic Commands":
  # Ensure that this is being run in the right directory
  assert "tests" notin string(p.getCurrentDir())

  test "version command":
    let (output, exitCode) = execCmdEx(BinaryPath & " version")
    check exitCode == 0
    check output.strip() == "0.1.0"

  test "intro command":
    let (output, exitCode) = execCmdEx(BinaryPath & " intro")
    check exitCode == 0
    check "context7" in output
    check "library documentation" in output

  test "no arguments shows usage":
    let (output, exitCode) = execCmdEx(BinaryPath)
    check exitCode == 1
    check "Usage" in output

  test "unknown command":
    let (output, exitCode) = execCmdEx(BinaryPath & " unknown")
    check exitCode == 1
    check "Unknown command" in output

suite "Configuration":
  test "config file parsing":
    # Create temp config
    let tempDir = getTempDir() / "context7-test"
    createDir(tempDir)
    let configPath = tempDir / "config.json"

    writeFile(configPath, """
{
  // Test comment
  "api_key": "test-key-123",
  /* Multi-line
     comment */
  "cache_dir": "/tmp/test-cache"
}
""")

    # Note: Full config testing would require modifying the binary
    # to accept custom config paths or use XDG_CONFIG_HOME
    removeFile(configPath)
    removeDir(tempDir)

when isMainModule:
  echo "Running basic tests..."
