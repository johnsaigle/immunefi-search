# Agent Guidelines for immunefi-search

## Build/Test/Lint Commands
- **Run list mode**: `./bin/immunefi-search --list` (or just `./bin/immunefi-search`)
- **Run search mode**: `GITHUB_TOKEN=xxx ./bin/immunefi-search --search "pattern"`
- **Legacy monolithic script**: `ruby immunefi-search.rb` (backup)
- **Lint code**: `rubocop` (available globally)
- **No test framework** currently configured

## Project Structure (Modular)
- **bin/immunefi-search** - Main executable entry point
- **lib/immunefi_search.rb** - Main orchestrator class
- **lib/immunefi_search/** - Modular components:
  - `config.rb` - Configuration constants and settings
  - `cli.rb` - Command line interface and argument parsing
  - `bounty_manager.rb` - Immunefi API operations and bounty data management
  - `github_searcher.rb` - GitHub API search operations (Phase 1 & 2)
  - `repository_filter.rb` - Repository filtering and cross-referencing logic
  - `rate_limiter.rb` - GitHub API rate limiting and delay management
  - `result_formatter.rb` - Output formatting for list and search modes
- **data/** - Cached bounty data and project details
- **Gemfile** - Ruby dependency management
- **Legacy files**: `script.rb`, `immunefi-search.rb`, `code-search/`

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
