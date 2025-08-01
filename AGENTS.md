# Agent Guidelines for ruby-immunefi

## Autodidact automation
- The author is an experienced programmer but new to Ruby. Code suggestions should be done according to Ruby best practices. Ruby idioms and best practices should be explained to the programmer alongside other work.

## Build/Test/Lint Commands
- **Run script**: `ruby script.rb`
- **Syntax check**: `ruby -c script.rb`
- **No formal test suite** - this is a simple Ruby script project

## Code Style & Conventions
- **Language**: Ruby 3.4.4
- **Indentation**: 4 spaces (as seen in script.rb)
- **String literals**: Single quotes preferred, double quotes for interpolation
- **Constants**: ALL_CAPS with underscores (e.g., `PROGRAMS_URL`, `PROJECT_FILE`)
- **Variables**: snake_case (e.g., `project_details`, `project_uri`)
- **Method calls**: Use parentheses for clarity in method calls with arguments
- **File operations**: Use `FileUtils` for directory operations, `File.write/read` for file I/O
- **HTTP**: Use `Net::HTTP` with proper SSL handling
- **Error handling**: Use `raise` for HTTP errors, check response codes explicitly
- **JSON**: Use `JSON.parse` and `JSON.pretty_generate` for formatting
- **Comments**: Include purpose comments at top of files with `# Purpose:`
- **Output**: Use `puts` for user-facing output, include descriptive messages

## Project Structure
- Main script: `script.rb` - Immunefi bug bounty program search tool
- Data directory: `data/` for cached JSON files and project details
- No test files or configuration files present
