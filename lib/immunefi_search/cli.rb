require 'optparse'

module ImmuneFiSearch
  class CLI
    def initialize
      @options = {}
    end

    def parse_arguments
      OptionParser.new do |opts|
        opts.banner = 'Usage: immunefi-search [options]'
        opts.separator ''
        opts.separator 'Modes:'

        opts.on('-l', '--list', 'List all qualifying Immunefi bounties (default)') do
          @options[:mode] = :list
        end

        opts.on('-s', '--search QUERY', 'Search GitHub for code patterns and cross-reference with bounties') do |query|
          @options[:mode] = :search
          @options[:query] = query
        end

        opts.separator ''
        opts.separator 'Options:'

        opts.on('-r', '--repo OWNER/REPO', 'Search in specific repository (use with --search)') do |repo|
          @options[:repo] = repo
        end

        opts.on('-f', '--full', 'Run comprehensive search: global + high-value repositories (use with --search)') do
          @options[:full] = true
        end

        opts.on('-v', '--verbose', 'Show detailed asset information in list mode') do
          @options[:verbose] = true
        end

        opts.on('-h', '--help', 'Show this help message') do
          puts opts
          exit
        end
      end.parse!

      # Default to list mode if no mode specified
      @options[:mode] ||= :list

      validate_arguments
      @options
    end

    private

    def validate_arguments
      return unless @options[:mode] == :search

      if @options[:query].nil? || @options[:query].strip.empty?
        puts 'Error: Search query is required for search mode'
        puts "Usage: immunefi-search --search 'your search term'"
        exit 1
      end

      # Check for GITHUB_TOKEN in search mode
      unless ENV['GITHUB_TOKEN']
        puts 'Error: GITHUB_TOKEN environment variable is required for search mode'
        puts 'Please set your GitHub token:'
        puts '  export GITHUB_TOKEN=your_github_token_here'
        puts ''
        puts 'Or run with the token:'
        if @options[:repo]
          puts "  GITHUB_TOKEN=your_token ./bin/immunefi-search --search '#{@options[:query]}' --repo #{@options[:repo]}"
        elsif @options[:full]
          puts "  GITHUB_TOKEN=your_token ./bin/immunefi-search --search '#{@options[:query]}' --full"
        else
          puts "  GITHUB_TOKEN=your_token ./bin/immunefi-search --search '#{@options[:query]}'"
        end
        exit 1
      end

      # Validate conflicting flags
      if @options[:repo] && @options[:full]
        puts 'Error: --repo and --full flags cannot be used together'
        puts 'Use --repo for single repository search, or --full for comprehensive search'
        exit 1
      end

      # Validate repo format if specified
      return unless @options[:repo] && !@options[:repo].match?(%r{\A[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+\z})

      puts 'Error: Repository must be in OWNER/REPO format'
      puts 'Example: --repo wormhole-foundation/wormhole'
      exit 1
    end
  end
end
