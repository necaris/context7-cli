## context7 CLI tool
##
## Tool for AI agents to retrieve library documentation via Context7.com API

import std/[os, parseopt]
import types, commands

const Version = "0.1.0"

proc showVersion() =
  echo Version

proc showIntro() =
  echo """You have access to `context7`, a CLI for fetching up-to-date library documentation.

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
Do not rely on training data — it may be outdated."""

type
  CommandOpts = object
    command: string
    args: seq[string]
    query: string
    format: OutputFormat
    apiKey: string
    cacheDir: string
    noCache: bool
    refreshCache: bool
    verbose: bool

proc parseArgs(): CommandOpts =
  result.format = fmtText # Default format
  result.args = @[]

  var parser = initOptParser(
    shortNoVal = {'v'},
    longNoVal = @["no-cache", "refresh-cache", "verbose", "version", "help"]
  )

  # First arg is command (or --version/--help flag)
  parser.next()
  if parser.kind == cmdArgument:
    result.command = parser.key
  elif parser.kind in {cmdShortOption, cmdLongOption}:
    case parser.key
    of "version":
      showVersion()
      quit(0)
    of "help", "h":
      echo "Usage: context7 <command> [options]"
      echo "Run 'context7 intro' for usage guide"
      quit(0)
    of "verbose", "v":
      result.verbose = true
    else:
      echo "Usage: context7 <command> [options]"
      quit(1)
  else:
    echo "Usage: context7 <command> [options]"
    quit(1)

  # Parse remaining args
  while true:
    parser.next()
    case parser.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case parser.key
      of "query", "q":
        result.query = parser.val
      of "format", "f":
        case parser.val
        of "json":
          result.format = fmtJson
        of "md", "markdown":
          result.format = fmtMarkdown
        of "txt", "text":
          result.format = fmtText
        else:
          stderr.writeLine("Unknown format: " & parser.val)
          quit(1)
      of "api-key":
        result.apiKey = parser.val
      of "cache-dir":
        result.cacheDir = parser.val
      of "no-cache":
        result.noCache = true
      of "refresh-cache":
        result.refreshCache = true
      of "verbose", "v":
        result.verbose = true
      of "version":
        showVersion()
        quit(0)
      of "help", "h":
        echo "Usage: context7 <command> [options]"
        echo "Run 'context7 intro' for usage guide"
        quit(0)
      else:
        stderr.writeLine("Unknown option: " & parser.key)
        quit(1)
    of cmdArgument:
      result.args.add(parser.key)

proc main() =
  if paramCount() == 0:
    echo "Usage: context7 <command> [options]"
    echo "Run 'context7 intro' for usage guide"
    quit(1)

  let opts = parseArgs()

  case opts.command
  of "version":
    showVersion()
  of "intro":
    showIntro()
  of "search":
    if opts.args.len == 0:
      stderr.writeLine("Error: search requires a library name")
      quit(1)
    let libraryName = opts.args[0]
    let query = if opts.query != "": opts.query else: libraryName
    search(libraryName, query, opts.format, opts.apiKey, opts.verbose,
           opts.noCache, opts.refreshCache)
  of "get":
    if opts.args.len == 0:
      stderr.writeLine("Error: get requires a library ID")
      quit(1)
    if opts.query == "":
      stderr.writeLine("Error: get requires --query")
      quit(1)
    let libraryId = opts.args[0]
    getContext(libraryId, opts.query, opts.format, opts.apiKey, opts.verbose,
               opts.noCache, opts.refreshCache)
  of "doc":
    if opts.args.len == 0:
      stderr.writeLine("Error: doc requires a library name")
      quit(1)
    let libraryName = opts.args[0]
    let query = if opts.query != "": opts.query else: libraryName
    doc(libraryName, query, opts.format, opts.apiKey, opts.verbose,
        opts.noCache, opts.refreshCache)
  else:
    stderr.writeLine("Unknown command: " & opts.command)
    quit(1)

when isMainModule:
  main()
