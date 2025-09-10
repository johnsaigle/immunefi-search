# immunefi-search

Find code patterns in high-value crypto bug bounty programs (>$100k).

## Quick Start

```bash
# 1. List 99 high-value bounty programs  
./bin/immunefi-search

# 2. Search for code patterns (need GitHub token)
export GITHUB_TOKEN="your_token_here"
./bin/immunefi-search --search "mu.Lock()"
```

## Search Examples

```bash
# Search specific repository
./bin/immunefi-search --search "import" --repo wormhole-foundation/wormhole

# Search all repos in organization  
./bin/immunefi-search --search "mu.Lock()" --org wormhole-foundation

# Comprehensive search (global + bounty repos)
./bin/immunefi-search --search "vulnerability" --full

# Filter by programming language
./bin/immunefi-search --search "transfer" --language solidity
```

## Setup

1. **Install Ruby 3.x**
2. **Get GitHub token** (for search): [github.com/settings/tokens](https://github.com/settings/tokens)
3. **Run**: `export GITHUB_TOKEN="your_token_here"`

## All Options

```bash
./bin/immunefi-search [options]

Modes:
  -l, --list                       List bounties (default)
  -s, --search QUERY               Search code patterns

Search Scope:
  -r, --repo OWNER/REPO           Search single repository  
  -o, --org ORGANIZATION          Search all repos in organization
  -f, --full                      Comprehensive search (global + high-value)

Filters:
  -L, --language LANG             Filter by language: go, rust, solidity, move
  
Other:
  -v, --verbose                   Detailed bounty info (list mode)
  -h, --help                      Show help
```

## What It Searches

- **Target Languages**: Go, Rust, Solidity, Move
- **Bounty Threshold**: >$100k programs only  
- **Repository Count**: 99 high-value bounty repositories
- **Organizations**: LayerZero, Wormhole, MakerDAO, Chainlink, Lido, etc.

## Rate Limits

- **Without token**: 10 requests/minute
- **With token**: 30 requests/minute + 5,000/hour
- Auto-handles rate limiting with delays and clear error messages
