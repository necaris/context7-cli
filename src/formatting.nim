## Shared formatting helpers for search results
##
## Extracted from commands.nim to eliminate duplication between
## `search`, `doc`, and test helpers.

import std/[json, strutils, strformat]

proc parseSearchResults*(body: string): JsonNode =
  ## Parse API response, handling both {"results":[...]} and [...] forms.
  ## Raises on unexpected format or invalid JSON.
  let parsed = parseJson(body)

  if parsed.kind == JArray:
    return parsed
  elif parsed.kind == JObject and parsed.hasKey("results"):
    return parsed["results"]
  else:
    raise newException(ValueError, "Unexpected API response format")

proc truncateDesc*(desc: string, maxLen = 60): string =
  ## Truncate description with "..." suffix.
  if desc.len > maxLen:
    desc[0 .. (maxLen - 4)] & "..."
  else:
    desc

proc formatSearchTable*(results: JsonNode): string =
  ## Render results as a markdown table (header + rows).
  var lines: seq[string] = @[]

  lines.add("| Library | ID | Score | Description |")
  lines.add("|---|---|---|---|")

  for item in results:
    let title = item["title"].getStr()
    let id = item["id"].getStr()
    let score = item["benchmarkScore"].getFloat()
    let shortDesc = truncateDesc(item["description"].getStr())
    lines.add(&"| {title} | {id} | {score:.1f} | {shortDesc} |")

  result = lines.join("\n")

proc formatOtherMatches*(results: JsonNode, skip = 1, maxExtra = 3): string =
  ## Render "Other matches" bullet list, skipping the first `skip` entries.
  var lines: seq[string] = @[]

  lines.add("---")
  lines.add("## Other matches")

  let endIdx = min(skip + maxExtra, results.len)
  for i in skip ..< endIdx:
    let item = results[i]
    let title = item["title"].getStr()
    let id = item["id"].getStr()
    let score = item["benchmarkScore"].getFloat()
    lines.add(&"- **{title}** ({id}) - Score: {score:.1f}")

  result = lines.join("\n")
