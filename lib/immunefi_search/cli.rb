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
      return unless @options[:query].nil? || @options[:query].strip.empty?

      puts 'Error: Search query is required for search mode'
      puts "Usage: immunefi-search --search 'your search term'"
      exit 1
    end
  end
end
