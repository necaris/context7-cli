## Configuration file parsing and environment setup

import std/[os, json, strutils]

const DefaultBaseUrl* = "https://context7.com"

proc stripJsonComments(content: string): string =
  ## Remove // and /* */ comments from JSON content, respecting strings
  result = ""
  var i = 0
  var inString = false
  
  while i < content.len:
    let c = content[i]
    
    if not inString:
      if i < content.len - 1:
        # Handle // comments
        if c == '/' and content[i+1] == '/':
          # Skip until end of line
          inc i, 2
          while i < content.len and content[i] != '\n':
            inc i
          continue

        # Handle /* */ comments
        if c == '/' and content[i+1] == '*':
          inc i, 2
          # Skip until */
          while i < content.len - 1:
            if content[i] == '*' and content[i+1] == '/':
              inc i, 2
              break
            inc i
          continue
    
    # Check for string start/end
    # Note: simplified handling of escaped quotes, assuming valid JSON
    if c == '"':
      var isEscaped = false
      if i > 0:
        var backslashCount = 0
        var j = i - 1
        while j >= 0 and content[j] == '\\':
          inc backslashCount
          dec j
        if backslashCount mod 2 != 0:
          isEscaped = true
      
      if not isEscaped:
        inString = not inString
    
    result.add(c)
    inc i

proc getConfigPath*(): string =
  ## Get the path to the config file
  let xdgConfig = getEnv("XDG_CONFIG_HOME")
  if xdgConfig != "":
    return xdgConfig / "context7" / "config.json"
  else:
    return getHomeDir() / ".config" / "context7" / "config.json"

proc loadConfigFile*(): JsonNode =
  ## Load and parse config.json (returns nil if not found)
  let path = getConfigPath()
  if not fileExists(path):
    return nil

  try:
    let content = readFile(path)
    let stripped = stripJsonComments(content)
    return parseJson(stripped)
  except:
    stderr.writeLine("Warning: Failed to parse config file: " & getCurrentExceptionMsg())
    return nil

proc getContext7CacheDir*(config: JsonNode = nil): string =
  ## Determine cache directory from env/config/defaults
  # Check env var first
  result = getEnv("CONTEXT7_CACHE")
  if result != "":
    return

  # Check config file
  if config != nil and config.hasKey("cache_dir"):
    result = config["cache_dir"].getStr()
    if result != "":
      return

  # Use XDG or default
  let xdgCache = getEnv("XDG_CACHE_HOME")
  if xdgCache != "":
    result = xdgCache / "context7"
  else:
    result = getHomeDir() / ".cache" / "context7"

proc parseAuthInfo*(path: string): string =
  ## Parse .authinfo or .netrc format: machine api.context7.com password <key>
  if not fileExists(path):
    return ""

  try:
    let content = readFile(path)
    for line in content.splitLines():
      let parts = line.strip().split()
      if parts.len >= 4:
        # Look for: machine api.context7.com ... password <key>
        var i = 0
        while i < parts.len - 3:
          if parts[i] == "machine" and parts[i+1] == "api.context7.com":
            # Find password
            var j = i + 2
            while j < parts.len - 1:
              if parts[j] == "password":
                return parts[j+1]
              inc j
          inc i
  except:
    return ""

  return ""

proc getApiKey*(cliKey: string = ""): string =
  ## Resolve API key from various sources
  # 1. CLI flag
  if cliKey != "":
    return cliKey

  # 2. Environment variable
  result = getEnv("CONTEXT7_API_KEY")
  if result != "":
    return

  # 3. Config file
  let config = loadConfigFile()
  if config != nil and config.hasKey("api_key"):
    result = config["api_key"].getStr()
    if result != "":
      return

  # 4. ~/.authinfo
  result = parseAuthInfo(getHomeDir() / ".authinfo")
  if result != "":
    return

  # 5. ~/.netrc
  result = parseAuthInfo(getHomeDir() / ".netrc")
  if result != "":
    return

  # Not found
  return ""

proc getBaseUrl*(config: JsonNode = nil): string =
  ## Get base URL (for testing override)
  if config != nil and config.hasKey("base_url"):
    result = config["base_url"].getStr()
    if result != "":
      return

  return DefaultBaseUrl
