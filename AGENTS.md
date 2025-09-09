# Agent Guidelines for immunefi-search

## Build/Test/Lint Commands
- **Run list mode**: `ruby immunefi-search.rb --list` (or just `ruby immunefi-search.rb`)
- **Run search mode**: `GITHUB_TOKEN=xxx ruby immunefi-search.rb --search "pattern"`
- **Run search verbose**: `GITHUB_TOKEN=xxx ruby immunefi-search.rb --search "pattern" --verbose`
- **Legacy script**: `ruby script.rb` (still available)
- **Lint code**: `rubocop` (available globally)
- **No test framework** currently configured

## Project Structure
- Main script: `immunefi-search.rb` - combined Immunefi + GitHub search tool
- Legacy script: `script.rb` - original Immunefi-only search
- Data directory: `data/` - stores fetched project data and details
- Code search: `code-search/` - original GitHub search tool (merged into main)
- Ruby LSP config: `.ruby-lsp/` - development tooling

## Code Style Guidelines
- **Language**: Ruby 3.4.4
- **Indentation**: 4 spaces (as seen in script.rb)
- **String literals**: Single quotes preferred
- **Method calls**: Use parentheses for clarity in method calls with arguments
- **Constants**: ALL_CAPS with underscores (e.g., `PROGRAMS_URL`, `PROJECT_FILE`)
- **Variable naming**: snake_case for variables and methods
- **File operations**: Use `FileUtils` for directory operations
- **HTTP requests**: Use `Net::HTTP` with proper SSL handling
- **Error handling**: Use `raise` for HTTP errors, check response codes
- **JSON**: Use `JSON.parse` and `JSON.pretty_generate` for file I/O
- **Comments**: Include purpose comments at top of files with `# Purpose:`
