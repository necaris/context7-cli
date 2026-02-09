## Type definitions for context7 CLI

type
  OutputFormat* = enum
    fmtJson = "json"
    fmtMarkdown = "md"
    fmtText = "txt"

  Config* = object
    apiKey*: string
    cacheDir*: string
    baseUrl*: string
    noCache*: bool
    refreshCache*: bool
    verbose*: bool

  SearchResult* = object
    id*: string
    title*: string
    description*: string
    branch*: string
    totalTokens*: int
    totalSnippets*: int
    stars*: int
    trustScore*: float
    benchmarkScore*: float
    score*: float
    verified*: bool

  ApiError* = object of CatchableError
    statusCode*: int

  ## HTTP response for mockable fetcher
  HttpResponse* = object
    status*: int
    body*: string

  ## Mockable HTTP fetcher type
  HttpFetcher* = proc(url: string, headers: seq[(string, string)]): HttpResponse {.gcsafe.}
