## HTTP client with retry logic and caching

import std/[httpclient, uri, tables, strutils, json, os]
import types, config, cache

const
  Version = "0.1.0"
  RequestTimeout = 30000  # 30 seconds

# Mockable HTTP fetcher - can be replaced in tests
var httpFetchImpl*: HttpFetcher = nil

proc getUserAgent*(): string =
  ## Build User-Agent header
  when defined(macosx):
    let osName = "macOS"
  elif defined(linux):
    let osName = "Linux"
  elif defined(windows):
    let osName = "Windows"
  else:
    let osName = "Unknown"

  when defined(arm64) or defined(aarch64):
    let arch = "arm64"
  elif defined(amd64) or defined(x86_64):
    let arch = "x86_64"
  else:
    let arch = "unknown"

  return "context7-cli/" & Version & " (" & osName & "; " & arch & ")"

type
  ApiResponse* = object
    status*: int
    body*: string
    fromCache*: bool

proc makeRequest*(endpoint: string, params: Table[string, string],
                  apiKey: string, verbose: bool = false,
                  noCache: bool = false, refreshCache: bool = false): ApiResponse =
  ## Make HTTP request with caching and retry logic

  let configFile = loadConfigFile()
  let baseUrl = getBaseUrl(configFile)

  # Build URL
  var url = parseUri(baseUrl & endpoint)
  var queryParts: seq[string] = @[]
  for key, val in params:
    queryParts.add(key & "=" & encodeUrl(val))

  if queryParts.len > 0:
    url.query = queryParts.join("&")

  let urlStr = $url

  # Check cache first (unless noCache or refreshCache)
  if not noCache and not refreshCache:
    let cached = readCache(endpoint, params)
    if cached.status != 0:
      if verbose:
        stderr.writeLine("[cache] Hit: " & urlStr)
      return ApiResponse(
        status: cached.status,
        body: cached.body,
        fromCache: true
      )

  if verbose:
    stderr.writeLine("[http] GET " & urlStr)

  # Use mock fetcher if available (for testing)
  if httpFetchImpl != nil:
    let headers = @[
      ("User-Agent", getUserAgent()),
      ("Authorization", "Bearer " & apiKey)
    ]
    let resp = httpFetchImpl(urlStr, headers)
    if resp.status == 200:
      result = ApiResponse(status: resp.status, body: resp.body, fromCache: false)
      if not noCache:
        let ttl = getTtlForEndpoint(endpoint)
        writeCache(endpoint, params, resp.status, urlStr, resp.body, ttl)
      return result
    else:
      var err = new(ApiError)
      err.statusCode = resp.status
      err.msg = resp.body
      raise err

  # Make HTTP request with retries
  var client = newHttpClient(timeout = RequestTimeout)
  defer: client.close()

  client.headers = newHttpHeaders({
    "User-Agent": getUserAgent(),
    "Authorization": "Bearer " & apiKey
  })

  var lastError = ""
  var attempts = 0
  const maxAttempts = 3

  while attempts < maxAttempts:
    inc attempts

    try:
      let response = client.request(urlStr, httpMethod = HttpGet)
      let status = response.code.int
      let body = response.body

      if verbose:
        stderr.writeLine("[http] Status: " & $status)

      # Handle success
      if status == 200:
        result = ApiResponse(status: status, body: body, fromCache: false)

        # Write to cache (unless noCache)
        if not noCache:
          let ttl = getTtlForEndpoint(endpoint)
          writeCache(endpoint, params, status, urlStr, body, ttl)

        return result

      # Handle 301 redirect
      if status == 301:
        try:
          let jsonBody = parseJson(body)
          if jsonBody.hasKey("libraryId"):
            let newLibraryId = jsonBody["libraryId"].getStr()
            if verbose:
              stderr.writeLine("[http] Redirecting to: " & newLibraryId)

            # Update params and retry
            var newParams = params
            newParams["libraryId"] = newLibraryId
            return makeRequest(endpoint, newParams, apiKey, verbose, noCache, refreshCache)
        except:
          discard

      # Handle 202 (processing) - retry with delay
      if status == 202:
        if attempts < 5:
          if verbose:
            stderr.writeLine("[http] Library processing, retrying in 3s...")
          sleep(3000)
          continue
        else:
          lastError = "Library is still processing after 5 attempts"
          break

      # Handle 429 (rate limit) - exponential backoff
      if status == 429:
        let delay = 1000 * (1 shl (attempts - 1))  # 1s, 2s, 4s
        if verbose:
          stderr.writeLine("[http] Rate limited, retrying in " & $(delay div 1000) & "s...")
        sleep(delay)
        continue

      # Handle 5xx - exponential backoff
      if status >= 500:
        if attempts < maxAttempts:
          let delay = 1000 * (1 shl (attempts - 1))
          if verbose:
            stderr.writeLine("[http] Server error, retrying in " & $(delay div 1000) & "s...")
          sleep(delay)
          continue
        else:
          lastError = "Server error after " & $maxAttempts & " attempts"
          break

      # Other errors (400, 401, 403, 404, 422)
      try:
        let jsonBody = parseJson(body)
        if jsonBody.hasKey("error") and jsonBody.hasKey("message"):
          lastError = jsonBody["message"].getStr()
        else:
          lastError = body
      except:
        lastError = body

      var err = new(ApiError)
      err.statusCode = status
      err.msg = lastError
      raise err

    except HttpRequestError as e:
      # Check if it's a timeout (this will catch connection timeouts)
      if "timeout" in e.msg.toLowerAscii():
        lastError = "Network timeout"
        if attempts < maxAttempts:
          if verbose:
            stderr.writeLine("[http] Timeout, retrying...")
          continue
        else:
          stderr.writeLine(lastError)
          quit(2)
      else:
        # Other HTTP request errors
        lastError = e.msg
        if attempts < maxAttempts:
          if verbose:
            stderr.writeLine("[http] Request error, retrying...")
          continue

    except ApiError:
      raise

    except CatchableError as e:
      lastError = e.msg
      break

  # Failed after retries
  stderr.writeLine("Error: " & lastError)
  quit(1)
