## Command implementations for search, get, and doc

import std/[tables, json]
import types, config, http_client, formatting

proc requireApiKey(apiKey: string): string =
  ## Resolve API key or exit with error. Replaces 3 identical blocks.
  result = getApiKey(apiKey)
  if result == "":
    stderr.writeLine("Error: No API key found. Set CONTEXT7_API_KEY or use --api-key")
    quit(1)

proc search*(libraryName: string, query: string, format: OutputFormat,
             apiKey: string = "", verbose: bool = false,
             noCache: bool = false, refreshCache: bool = false) =
  ## Search for a library

  let key = requireApiKey(apiKey)

  # Make request
  let params = {"query": query, "libraryName": libraryName}.toTable
  let response = makeRequest("/api/v2/libs/search", params, key, verbose, noCache, refreshCache)

  # Parse and format output
  try:
    let results = parseSearchResults(response.body)

    case format
    of fmtJson:
      echo response.body

    of fmtMarkdown, fmtText:
      echo formatSearchTable(results)

  except JsonParsingError:
    stderr.writeLine("Error: Invalid JSON response from API")
    quit(1)
  except ValueError:
    stderr.writeLine("Error: Unexpected API response format")
    quit(1)
  except:
    stderr.writeLine("Error: " & getCurrentExceptionMsg())
    quit(1)

proc getContext*(libraryId: string, query: string, format: OutputFormat,
                 apiKey: string = "", verbose: bool = false,
                 noCache: bool = false, refreshCache: bool = false) =
  ## Get documentation context for a library

  let key = requireApiKey(apiKey)

  # Determine API type param based on format
  let apiType = if format == fmtJson: "json" else: "txt"

  # Make request
  let params = {"query": query, "libraryId": libraryId, "type": apiType}.toTable
  let response = makeRequest("/api/v2/context", params, key, verbose, noCache, refreshCache)

  # Output
  case format
  of fmtJson:
    # Wrap in object with id and content
    try:
      let jsonResp = %* {
        "id": libraryId,
        "content": response.body
      }
      echo $jsonResp
    except:
      stderr.writeLine("Error formatting JSON response")
      quit(1)

  of fmtMarkdown, fmtText:
    echo response.body

proc doc*(libraryName: string, query: string, format: OutputFormat,
          apiKey: string = "", verbose: bool = false,
          noCache: bool = false, refreshCache: bool = false) =
  ## Convenience command: search -> get context -> show other matches

  let key = requireApiKey(apiKey)

  # Step 1: Search for library
  if verbose:
    stderr.writeLine("[doc] Searching for library: " & libraryName)

  let searchParams = {"query": query, "libraryName": libraryName}.toTable
  let searchResponse = makeRequest("/api/v2/libs/search", searchParams, key, verbose, noCache, refreshCache)

  var searchResults: JsonNode
  try:
    searchResults = parseSearchResults(searchResponse.body)
  except:
    stderr.writeLine("Error: Invalid JSON response from search API")
    quit(1)

  # Check if we got results
  if searchResults.len == 0:
    stderr.writeLine("Error: No libraries found matching '" & libraryName & "'")
    quit(1)

  # Step 2: Get context for top result
  let topResult = searchResults[0]
  let libraryId = topResult["id"].getStr()

  if verbose:
    stderr.writeLine("[doc] Getting context for: " & libraryId)

  let apiType = if format == fmtJson: "json" else: "txt"
  let contextParams = {"query": query, "libraryId": libraryId, "type": apiType}.toTable
  let contextResponse = makeRequest("/api/v2/context", contextParams, key, verbose, noCache, refreshCache)

  # Step 3: Output main content
  case format
  of fmtJson:
    # Build other_matches array
    var otherMatches = newJArray()
    let endIdx = min(4, searchResults.len)  # Top result + 3 others
    for i in 1..<endIdx:
      let result = searchResults[i]
      otherMatches.add(%* {
        "title": result["title"].getStr(),
        "id": result["id"].getStr(),
        "score": result["benchmarkScore"].getFloat()
      })

    let jsonResp = %* {
      "id": libraryId,
      "content": contextResponse.body,
      "other_matches": otherMatches
    }
    echo $jsonResp

  of fmtMarkdown, fmtText:
    # Output main content
    echo contextResponse.body

    # Append other matches section if there are more results
    if searchResults.len > 1:
      echo ""
      echo formatOtherMatches(searchResults)
