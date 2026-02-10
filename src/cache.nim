## Cache management for API responses

import std/[os, times, strutils, tables, algorithm]
import checksums/sha1
import config

type
  CacheEntry* = object
    status*: int
    url*: string
    body*: string
    timestamp*: int64
    ttl*: int

proc hashKey(endpoint: string, params: Table[string, string]): string =
  ## Create SHA-256 hash from endpoint and sorted params
  var parts: seq[string] = @[endpoint]

  # Sort params by key for consistency
  var sortedKeys: seq[string]
  for key in params.keys:
    sortedKeys.add(key)
  sort(sortedKeys, system.cmp)

  for key in sortedKeys:
    parts.add(key & "=" & params[key])

  let combined = parts.join("&")
  return $secureHash(combined)

proc getCachePath*(endpoint: string, params: Table[string, string]): string =
  ## Get the cache file path for a request
  let hash = hashKey(endpoint, params)
  let cacheDir = getContext7CacheDir()
  return cacheDir / hash & ".cache"

proc ensureCacheDir*() =
  ## Create cache directory if it doesn't exist
  let cacheDir = getContext7CacheDir()
  if not dirExists(cacheDir):
    createDir(cacheDir)

proc readCache*(endpoint: string, params: Table[string, string]): CacheEntry =
  ## Read cache entry if valid, returns empty entry if miss
  result = CacheEntry()

  let path = getCachePath(endpoint, params)
  if not fileExists(path):
    return

  try:
    let content = readFile(path)

    # Parse header section
    var lines = content.split('\n')
    var i = 0
    var headerParsed = false

    while i < lines.len:
      let line = lines[i]

      if line.strip() == "":
        # Found delimiter, rest is body
        headerParsed = true
        result.body = lines[(i+1)..^1].join("\n")
        break

      if line.contains(":"):
        let parts = line.split(":", 1)
        if parts.len == 2:
          let key = parts[0].strip()
          let value = parts[1].strip()

          case key
          of "timestamp":
            result.timestamp = parseInt(value)
          of "ttl":
            result.ttl = parseInt(value)
          of "status":
            result.status = parseInt(value)
          of "url":
            result.url = value

      inc i

    if not headerParsed:
      # Invalid cache file
      return CacheEntry()

    # Check expiration
    let now = getTime().toUnix()
    if now > result.timestamp + result.ttl:
      # Expired
      return CacheEntry()

  except:
    # Read error, treat as miss
    return CacheEntry()

proc writeCache*(endpoint: string, params: Table[string, string],
                 status: int, url: string, body: string, ttl: int) =
  ## Write response to cache
  ensureCacheDir()

  let path = getCachePath(endpoint, params)
  let timestamp = getTime().toUnix()

  var content = ""
  content.add("nim-context7-cache: v1\n")
  content.add("timestamp: " & $timestamp & "\n")
  content.add("ttl: " & $ttl & "\n")
  content.add("status: " & $status & "\n")
  content.add("url: " & url & "\n")
  content.add("\n")
  content.add(body)

  try:
    writeFile(path, content)
  except:
    # Fail silently - caching is optional
    discard

proc getTtlForEndpoint*(endpoint: string): int =
  ## Get TTL in seconds based on endpoint
  if endpoint.contains("/api/v2/libs/search"):
    return 24 * 60 * 60  # 24 hours
  elif endpoint.contains("/api/v2/context"):
    return 60 * 60  # 1 hour
  else:
    return 60 * 60  # Default 1 hour
