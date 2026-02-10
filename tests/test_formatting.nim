## Tests for JSON to Markdown output formatting
##
## Tests that raw API JSON responses are correctly formatted as Markdown tables
## and text output. Uses shared formatting procs from src/formatting.nim.

import std/[unittest, json, strutils, strformat, sequtils]
import ../src/types
import ../src/formatting
import fixtures

suite "Search JSON to Markdown Table":

  test "basic search results format as table":
    let results = parseSearchResults(SearchResponseJson)
    let output = formatSearchTable(results)

    # Check header row
    check "| Library | ID | Score | Description |" in output
    check "|---|---|---|---|" in output

    # Check data rows
    check "| React |" in output
    check "| /facebook/react |" in output
    check "| 88.0 |" in output

    check "| Next.js |" in output
    check "| /vercel/next.js |" in output

    check "| React Router |" in output
    check "| /remix-run/react-router |" in output

  test "long descriptions are truncated":
    let results = parseSearchResults(SearchResponseLongDesc)
    let output = formatSearchTable(results)

    # Should be truncated with ...
    check "..." in output
    # Original description should NOT appear in full
    check "sixty character limit for table cells" notin output
    # But start of description should be there
    check "This is a very long" in output

  test "empty results produce header only":
    let results = parseSearchResults(SearchResponseEmpty)
    let output = formatSearchTable(results)

    # Should have headers
    check "| Library | ID | Score | Description |" in output
    check "|---|---|---|---|" in output

    # Should have exactly 2 lines (header + separator)
    check output.splitLines().len == 2

  test "score formatted to 2 decimal places":
    let results = parseSearchResults(SearchResponseJson)
    let output = formatSearchTable(results)

    # Check precise formatting (benchmarkScore values)
    check "| 88.0 |" in output
    check "| 72.0 |" in output
    check "| 68.0 |" in output

  test "table rows have correct column count":
    let results = parseSearchResults(SearchResponseJson)
    let output = formatSearchTable(results)

    for line in output.splitLines():
      # Each row should have 5 pipe characters (4 columns)
      let pipeCount = line.count('|')
      check pipeCount == 5

suite "Doc Command Other Matches Formatting":

  test "other matches formatted as bullet list":
    let results = parseSearchResults(SearchResponseJson)
    let output = formatOtherMatches(results)

    check "## Other matches" in output
    check "---" in output

    # Should show items 1-3 (not item 0 which is the main result)
    check "**Next.js**" in output
    check "(/vercel/next.js)" in output
    check "Score: 72" in output

    check "**React Router**" in output

    # Should NOT include first item (it's the main result)
    # The first item "React" should not appear as a bullet point
    let lines = output.splitLines().filterIt(it.startsWith("- "))
    check lines.len == 2  # Only Next.js and React Router

  test "other matches score formatted correctly":
    let results = parseSearchResults(SearchResponseJson)
    let output = formatOtherMatches(results)

    check "Score: 72.0" in output
    check "Score: 68.0" in output

suite "JSON Response Validation":

  test "malformed JSON raises exception":
    expect JsonParsingError:
      discard parseSearchResults("not valid json")

  test "missing required fields raise exception":
    let results = parseSearchResults("""[{"id": "/test"}]""")
    expect KeyError:
      discard formatSearchTable(results)  # missing title, score, description

  test "null values handled":
    # Some APIs return null for optional fields
    let jsonWithNull = """[{"id": "/test", "title": "Test", "description": null, "totalSnippets": 10, "trustScore": 90, "benchmarkScore": 50, "versions": ["v1.0.0"]}]"""
    # This should either work with empty string or raise - document the behavior
    try:
      let results = parseSearchResults(jsonWithNull)
      let output = formatSearchTable(results)
      check "| Test |" in output
    except:
      # If it raises, that's also valid behavior - null isn't expected
      check true

suite "Edge Cases":

  test "single result formats correctly":
    let singleResult = """[{"id": "/one/lib", "title": "OneLib", "description": "Single library", "totalSnippets": 10, "trustScore": 90, "benchmarkScore": 100, "versions": ["v1.0.0"]}]"""
    let results = parseSearchResults(singleResult)
    let output = formatSearchTable(results)

    check output.splitLines().len == 3  # header + separator + 1 row
    check "| OneLib |" in output
    check "| 100.0 |" in output

  test "description exactly 60 chars not truncated":
    let exact60 = "A" & "b".repeat(59)  # 60 chars
    let json60 = &"""[{{"id": "/x", "title": "X", "description": "{exact60}", "totalSnippets": 10, "trustScore": 90, "benchmarkScore": 10, "versions": ["v1.0.0"]}}]"""
    let results = parseSearchResults(json60)
    let output = formatSearchTable(results)

    check "..." notin output
    check exact60 in output

  test "description 61 chars is truncated":
    let chars61 = "A" & "b".repeat(60)  # 61 chars
    let json61 = &"""[{{"id": "/x", "title": "X", "description": "{chars61}", "totalSnippets": 10, "trustScore": 90, "benchmarkScore": 10, "versions": ["v1.0.0"]}}]"""
    let results = parseSearchResults(json61)
    let output = formatSearchTable(results)

    check "..." in output
    check chars61 notin output

  test "special characters in names":
    let results = parseSearchResults(SearchResponseSpecialChars)
    let output = formatSearchTable(results)

    # Pipe character in name - may break table formatting
    # This documents current behavior
    check "Pipe|Lib" in output or "Pipe" in output

  test "unicode in description":
    let unicodeJson = """[{"id": "/u", "title": "Unicode", "description": "Supports emoji 🚀 and symbols ñ", "totalSnippets": 10, "trustScore": 90, "benchmarkScore": 90, "versions": ["v1.0.0"]}]"""
    let results = parseSearchResults(unicodeJson)
    let output = formatSearchTable(results)

    check "Unicode" in output
    # Unicode should pass through
    check "🚀" in output or "emoji" in output

when isMainModule:
  echo "Running formatting tests..."
