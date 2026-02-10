## Shared test fixture constants
##
## All fixture data lives here so test_api, test_formatting, and
## test_integration can import a single module instead of duplicating
## the same JSON blobs.

# ---------------------------------------------------------------------------
# Search responses
# ---------------------------------------------------------------------------

const SearchResponseFixture* = """{"results":[{"id":"/websites/react_dev","title":"React","description":"React is a JavaScript library for building user interfaces. It allows developers to create interactive web and native applications using reusable components, enabling efficient and scalable UI development.","branch":"main","lastUpdateDate":"2026-02-05T09:48:38.174Z","state":"finalized","totalTokens":861433,"totalSnippets":5574,"stars":-1,"trustScore":10,"benchmarkScore":89.2,"versions":[],"score":0.8,"vip":true,"verified":true},{"id":"/reactjs/react.dev","title":"React","description":"React.dev is the official documentation website for React, a JavaScript library for building user interfaces, providing guides, API references, and tutorials.","branch":"main","lastUpdateDate":"2026-02-08T03:31:53.731Z","state":"finalized","totalTokens":840202,"totalSnippets":5546,"stars":11311,"trustScore":10,"benchmarkScore":83.4,"versions":[],"score":0.50902075,"vip":true,"verified":true},{"id":"/websites/18_react_dev","title":"React 18","description":"React is a JavaScript library for building web and native user interfaces out of individual components, designed for creating interactive and dynamic applications.","branch":"main","lastUpdateDate":"2026-01-06T01:56:14.759Z","state":"finalized","totalTokens":521369,"totalSnippets":3921,"stars":-1,"trustScore":10,"benchmarkScore":82.6,"versions":[],"score":0.6707667,"vip":true,"verified":true},{"id":"/marmelab/react-admin","title":"React-admin","description":"A frontend Framework for building single-page applications running in the browser on top of REST/GraphQL APIs, using TypeScript, React, react-router, react-hook-form, react-query, and Material Design.","branch":"master","lastUpdateDate":"2025-11-17T15:07:12.875Z","state":"finalized","totalTokens":866758,"totalSnippets":4345,"stars":25717,"trustScore":9.5,"benchmarkScore":92.8,"versions":["v2_9_9","v4.16.0","v2.9.0","v3.19.0","v5_10_2"],"score":0.6124619,"vip":true,"verified":true},{"id":"/remix-run/react-router","title":"React Router","description":"React Router is a multi-strategy router for React, bridging React 18 to 19, usable as a framework or a library.","branch":"main","lastUpdateDate":"2026-02-07T03:18:37.174Z","state":"finalized","totalTokens":260988,"totalSnippets":2034,"stars":54762,"trustScore":7.5,"benchmarkScore":83.5,"versions":["7.6.2","react-router@7.5.3","react_router_7_8_2","react-router_7.9.4","v5.2.1","v6.3.0"],"score":0.5042116,"vip":true,"verified":true}]}"""

const SearchResponseJson* = """[
  {"id": "/facebook/react", "title": "React", "description": "A JavaScript library for building user interfaces", "totalSnippets": 1250, "trustScore": 95, "benchmarkScore": 88, "versions": ["v18.2.0"]},
  {"id": "/vercel/next.js", "title": "Next.js", "description": "The React Framework for Production", "totalSnippets": 890, "trustScore": 90, "benchmarkScore": 72, "versions": ["v15.0.0"]},
  {"id": "/remix-run/react-router", "title": "React Router", "description": "Declarative routing for React", "totalSnippets": 450, "trustScore": 85, "benchmarkScore": 68, "versions": ["v6.0.0"]}
]"""

const SearchResponseLongDesc* = """[
  {"id": "/some/lib", "title": "LongLib", "description": "This is a very long description that should be truncated because it exceeds the sixty character limit for table cells", "totalSnippets": 100, "trustScore": 80, "benchmarkScore": 85, "versions": ["v1.0.0"]}
]"""

const SearchResponseEmpty* = "[]"

const SearchResponseSpecialChars* = """[
  {"id": "/org/pipe-lib", "title": "Pipe|Lib", "description": "Contains | pipe and other chars", "totalSnippets": 50, "trustScore": 70, "benchmarkScore": 50, "versions": ["v1.0.0"]}
]"""

const LongDescriptionResponse* = """[
  {"id": "/test/longdesc", "title": "LongDescLib", "description": "This is a very long description that exceeds sixty characters and should be truncated in the markdown table output", "totalSnippets": 100, "trustScore": 80, "benchmarkScore": 85, "versions": ["v1.0.0"]}
]"""

# ---------------------------------------------------------------------------
# Context responses
# ---------------------------------------------------------------------------

const ContextResponseFixture* = """# React Documentation

## useState Hook

The `useState` hook lets you add state to functional components.

```javascript
const [count, setCount] = useState(0);
```

## useEffect Hook

The `useEffect` hook lets you perform side effects in components.

```javascript
useEffect(() => {
  document.title = `You clicked ${count} times`;
}, [count]);
```
"""

const ContextResponseJson* = """[
  {"title": "Getting Started", "content": "React is a JavaScript library for building user interfaces.", "source": "react.dev/docs/getting-started"},
  {"title": "Installation", "content": "npm install react react-dom", "source": "react.dev/docs/installation"},
  {"title": "Basic Example", "content": "import React from 'react';\n\nfunction App() {\n  return <h1>Hello, World!</h1>;\n}", "source": "react.dev/docs/example"}
]"""

const ContextResponseText* = """# React Documentation

## Getting Started

React is a JavaScript library for building user interfaces.

### Installation

```bash
npm install react react-dom
```

### Basic Example

```jsx
import React from 'react';

function App() {
  return <h1>Hello, World!</h1>;
}
```

## Components

Components let you split the UI into independent, reusable pieces."""

# ---------------------------------------------------------------------------
# Error / misc responses
# ---------------------------------------------------------------------------

const ErrorResponse* = """{"error": "not_found", "message": "Library not found"}"""

const EmptySearchResponse* = "[]"
