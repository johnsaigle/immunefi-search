# immunefi-search

Combined tool for Immunefi bug bounty analysis and GitHub code search integration.

## Features

- **List Mode**: Display all qualifying Immunefi bounties
- **Search Mode**: Search GitHub for code patterns and cross-reference with bounty repositories

## Usage

### List All Bounties (Default Mode)

```bash
ruby immunefi-search.rb --list
# or simply
ruby immunefi-search.rb
```

Displays concise list of bug bounty programs that match:
- **Languages**: Go, Rust, Solidity, Move
- **Asset types**: Blockchain/DLT or Smart Contract  
- **Bounty threshold**: >$100k

For detailed asset information:
```bash
ruby immunefi-search.rb --list --verbose
```

### Search GitHub Code + Cross-Reference

```bash
export GITHUB_TOKEN="your_github_token_here"
ruby immunefi-search.rb --search "log.topics[0]"
```

For detailed output including code fragments and descriptions:
```bash
ruby immunefi-search.rb --search "log.topics[0]" --verbose
```

This will:
1. Search GitHub for the specified code pattern across target languages
2. Cross-reference results with Immunefi bounty repositories
3. Display matches that exist in both GitHub and Immunefi scopes
4. In verbose mode: show code fragments, repository descriptions, and bounty asset URLs

## Requirements

- Ruby 3.x
- For search mode: GitHub Personal Access Token set as `GITHUB_TOKEN` environment variable

## Output

### List Mode
**Default (concise)**:
- Project name with programming languages and max bounty
- Asset count and Immunefi URL

**Verbose mode adds**:
- Detailed bounty ranges by asset type and severity
- All in-scope blockchain/DLT and smart contract assets with URLs

### Search Mode  
For each GitHub/Immunefi match:
- Repository information and matched file details
- Match count (default mode)
- **Verbose mode adds**:
  - Code fragments containing the search pattern
  - Repository descriptions and bounty asset URLs
  - Highlighted text matches

## Data Caching

- Projects cached in `data/projects-YYYY-MM-DD.json`
- Project details cached in `data/project-details/`
- Automatic refresh when data is stale
