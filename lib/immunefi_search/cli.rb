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

        opts.on('-o', '--org ORGANIZATION', 'Search all repositories in organization (use with --search)') do |org|
          @options[:org] = org
        end

        opts.on('-f', '--full', 'Run comprehensive search: global + high-value repositories (use with --search)') do
          @options[:full] = true
        end

        opts.on('-L', '--language LANG',
                'Filter search to specific language: go, rust, solidity, move (use with --search)') do |lang|
          @options[:language] = lang.downcase
        end

        opts.on('-e', '--exact', 'Search for exact phrase match (use with --search)') do
          @options[:exact] = true
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
        command = "GITHUB_TOKEN=your_token ./bin/immunefi-search --search '#{@options[:query]}'"
        command += " --repo #{@options[:repo]}" if @options[:repo]
        command += " --org #{@options[:org]}" if @options[:org]
        command += ' --full' if @options[:full]
        command += " --language #{@options[:language]}" if @options[:language]
        command += ' --exact' if @options[:exact]
        puts "  #{command}"
        exit 1
      end

      # Validate conflicting flags
      exclusive_flags = [@options[:repo], @options[:org], @options[:full]].compact
      if exclusive_flags.size > 1
        flags = []
        flags << '--repo' if @options[:repo]
        flags << '--org' if @options[:org]
        flags << '--full' if @options[:full]
        puts "Error: #{flags.join(', ')} flags cannot be used together"
        puts 'Choose one: --repo for single repository, --org for organization, --full for comprehensive search'
        exit 1
      end

      # Validate language filter
      if @options[:language]
        require_relative 'config'
        valid_languages = ImmuneFiSearch::TARGET_LANGUAGES
        unless valid_languages.include?(@options[:language])
          puts "Error: Invalid language '#{@options[:language]}'"
          puts "Supported languages: #{valid_languages.join(', ')}"
          puts 'Example: --language go'
          exit 1
        end
      end

      # Validate repo format if specified
      return unless @options[:repo] && !@options[:repo].match?(%r{\A[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+\z})

      puts 'Error: Repository must be in OWNER/REPO format'
      puts 'Example: --repo wormhole-foundation/wormhole'
      exit 1
    end
  end
end
