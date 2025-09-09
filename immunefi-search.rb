#!/usr/bin/env ruby
# Purpose: Combined Immunefi Bug Bounty search tool with GitHub code search integration
require 'net/http'
require 'json'
require 'fileutils'
require 'optparse'

# Configuration
PROGRAMS_URL = 'https://raw.githubusercontent.com/infosec-us-team/Immunefi-Bug-Bounty-Programs-Unofficial/main/projects.json'
TARGET_LANGUAGES = %w[go rust solidity move]
MIN_BOUNTY = 100_000

class ImmuneFiSearch
  def initialize
    @date = Time.now.strftime('%Y-%m-%d')
    @project_file = "data/projects-#{@date}.json"
    @details_dir = 'data/project-details/'

    FileUtils.mkdir_p(@details_dir) unless Dir.exist?(@details_dir)
  end

  def run_list_mode(verbose = false)
    puts "Immunefi search for #{TARGET_LANGUAGES.join(', ').upcase} programs"
    puts 'Filtering for blockchain/DLT and smart contract bounties >$100k'
    puts ''

    projects = fetch_projects
    filter_and_display_projects(projects, verbose)
  end

  def run_search_mode(query)
    token = ENV['GITHUB_TOKEN']
    raise 'Please set GITHUB_TOKEN environment variable' unless token

    puts "Searching GitHub for: #{query}"
    puts 'Cross-referencing with Immunefi bounties...'

    # Check rate limit status
    check_rate_limit_status(token)
    puts ''

    # Fetch GitHub search results for each target language
    github_results = []
    search_languages = TARGET_LANGUAGES.reject { |lang| lang == 'move' } # GitHub doesn't have Move language support yet

    search_languages.each_with_index do |lang, index|
      puts "Searching #{lang.upcase} repositories... (#{index + 1}/#{search_languages.length})"

      results = search_github(query, lang, token)
      github_results += parse_github_results(results, lang) if results

      # Add a small delay between requests to be respectful to the API
      sleep(1) if index < search_languages.length - 1
    end

    puts "GitHub search completed. Found #{github_results.length} total results."

    # Load Immunefi bounty URLs for cross-reference
    bounty_repos = load_bounty_repositories

    # Cross-reference and display results (always verbose for search)
    display_cross_referenced_results(github_results, bounty_repos, true)
  end

  private

  def fetch_projects
    if File.exist?(@project_file)
      JSON.parse(File.read(@project_file))
    else
      puts 'Fetching projects from Immunefi...'
      uri = URI(PROGRAMS_URL)
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
        req = Net::HTTP::Get.new(uri)
        res = http.request req
        raise "HTTP Error: #{res.code} #{res.message}" unless res.code == '200'

        projects = JSON.parse(res.body)
        File.write(@project_file, JSON.pretty_generate(projects))
        projects
      end
    end
  end

  def filter_and_display_projects(projects, verbose = false)
    projects.each do |program|
      # Check if program uses any of our target languages
      program_languages = program['tags']['language'].map(&:downcase)
      language_match = TARGET_LANGUAGES.any? { |lang| program_languages.include?(lang) }
      next unless language_match

      # Fetch project details
      project_details = fetch_project_details(program['id'])
      next unless project_details

      # Check bounty criteria
      target_rewards = project_details.dig('pageProps', 'bounty', 'rewards')&.select do |reward|
        %w[blockchain_dlt smart_contract].include?(reward['assetType']) &&
          reward['maxReward'] && reward['maxReward'] > MIN_BOUNTY
      end
      next if target_rewards.nil? || target_rewards.empty?

      # Display project information
      display_project(program, project_details, target_rewards, program_languages, verbose)
    end
  end

  def fetch_project_details(project_id)
    project_details_file = "#{@details_dir}#{project_id}.json"

    if File.exist?(project_details_file)
      JSON.parse(File.read(project_details_file))
    else
      project_uri = URI("https://raw.githubusercontent.com/infosec-us-team/Immunefi-Bug-Bounty-Programs-Unofficial/main/project/#{project_id}.json")
      Net::HTTP.start(project_uri.hostname, project_uri.port, use_ssl: project_uri.scheme == 'https') do |http|
        req = Net::HTTP::Get.new(project_uri)
        res = http.request req
        return nil unless res.code == '200'

        project_details = JSON.parse(res.body)
        File.write(project_details_file, JSON.pretty_generate(project_details))
        project_details
      end
    end
  rescue JSON::ParserError
    nil
  end

  def display_project(program, project_details, target_rewards, program_languages, verbose = false)
    matching_languages = TARGET_LANGUAGES.select { |lang| program_languages.include?(lang) }
    language_display = matching_languages.map(&:upcase).join(', ')

    if verbose
      puts '=' * 60
      puts "PROJECT: #{program['project']} [#{language_display}]"
      puts "URL: https://immunefi.com/bounty/#{program['id']}"
      puts "Max Bounty: #{format_currency(project_details.dig('pageProps', 'bounty', 'maxBounty'))}"
      puts '=' * 60

      puts "\nBOUNTIES:"
      target_rewards.each do |reward|
        asset_type_display = reward['assetType'] == 'blockchain_dlt' ? 'Blockchain/DLT' : 'Smart Contract'
        min_reward = reward['minReward'] ? format_currency(reward['minReward']) : '0'
        max_reward = format_currency(reward['maxReward'])
        puts "  • #{asset_type_display}: $#{min_reward} - $#{max_reward} (#{reward['severity']})"
      end

      puts "\nASSETS:"
      asset_count = 0
      project_details.dig('pageProps', 'bounty', 'assets')&.each do |asset|
        next unless %w[blockchain_dlt smart_contract].include?(asset['type'])

        asset_count += 1

        puts "  • #{asset['description']}"
        puts "    Type: #{asset['type']}"
        puts "    URL: #{asset['url']}"
        puts ''
      end
      puts ''
    else
      # Concise output for non-verbose mode
      max_bounty = format_currency(project_details.dig('pageProps', 'bounty', 'maxBounty'))
      asset_count = project_details.dig('pageProps', 'bounty', 'assets')&.count do |asset|
        %w[blockchain_dlt smart_contract].include?(asset['type'])
      end || 0

      puts "#{program['project']} [#{language_display}] - $#{max_bounty} (#{asset_count} assets)"
      puts "  https://immunefi.com/bounty/#{program['id']}"
      puts ''
    end
  end

  def search_github(query, language, token)
    encoded_query = URI.encode_www_form_component("#{query} in:file language:#{language}")
    uri = URI("https://api.github.com/search/code?q=#{encoded_query}")

    req = Net::HTTP::Get.new(uri)
    req['Accept'] = 'application/vnd.github.v3.text-match+json'
    req['Authorization'] = "Bearer #{token}"

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      res = http.request(req)

      case res.code
      when '200'
        JSON.parse(res.body)
      when '403'
        handle_rate_limit(res, language)
        nil
      when '422'
        puts "GitHub API error for #{language}: Invalid search query or too complex"
        nil
      when '503'
        puts "GitHub API error for #{language}: Service temporarily unavailable"
        nil
      else
        puts "GitHub API error for #{language}: #{res.code} #{res.message}"
        nil
      end
    end
  rescue JSON::ParserError, StandardError => e
    puts "Error searching GitHub for #{language}: #{e.message}"
    nil
  end

  def check_rate_limit_status(token)
    uri = URI('https://api.github.com/rate_limit')
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{token}"

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      res = http.request(req)
      if res.code == '200'
        rate_info = JSON.parse(res.body)
        search_limit = rate_info.dig('resources', 'search')

        if search_limit
          remaining = search_limit['remaining']
          limit = search_limit['limit']
          reset_time = Time.at(search_limit['reset'])

          puts "GitHub API Status: #{remaining}/#{limit} search requests remaining"

          if remaining < TARGET_LANGUAGES.length
            puts "⚠️  Warning: Low rate limit remaining. Reset at #{reset_time.strftime('%H:%M:%S')}"
          end
        end
      end
    end
  rescue StandardError => e
    puts "Note: Could not check GitHub rate limit status (#{e.message})"
  end

  def handle_rate_limit(response, language)
    # Check if it's rate limiting or other 403 error
    rate_limit_remaining = response['X-RateLimit-Remaining']&.to_i
    rate_limit_reset = response['X-RateLimit-Reset']&.to_i

    if rate_limit_remaining == 0 && rate_limit_reset
      reset_time = Time.at(rate_limit_reset)
      wait_minutes = ((reset_time - Time.now) / 60).ceil

      puts "⚠️  GitHub API rate limit exceeded for #{language} searches"
      puts "   Rate limit will reset at: #{reset_time.strftime('%H:%M:%S')}"
      puts "   Wait time: ~#{wait_minutes} minutes"
      puts '   Note: Authenticated requests have higher limits (5,000/hour vs 10/minute)'

      # Check if the token looks like a personal access token
      if ENV['GITHUB_TOKEN']&.start_with?('ghp_')
        puts '   ✓ Using Personal Access Token (higher rate limits should apply)'
      else
        puts '   ⚠️  Consider using a GitHub Personal Access Token for higher rate limits'
      end
    elsif response.body&.include?('rate limit')
      puts "⚠️  GitHub API rate limit exceeded for #{language} searches"
      puts "   Response: #{response.body}"
    else
      puts "GitHub API 403 error for #{language}: #{response.message}"
      puts '   This might be due to insufficient permissions or repository access restrictions'
    end
  end

  def parse_github_results(results, language)
    return [] unless results['items']

    results['items'].map do |item|
      {
        filename: item['name'],
        filepath: item['path'],
        file_url: item['html_url'],
        sha: item['sha'],
        repo_url: item.dig('repository', 'html_url'),
        full_name: item.dig('repository', 'full_name'),
        description: item.dig('repository', 'description'),
        language: language,
        text_matches: extract_text_matches(item['text_matches'] || [])
      }
    end
  end

  def extract_text_matches(text_matches)
    text_matches.map do |match|
      next unless match['object_type'] == 'FileContent'

      {
        fragment: match['fragment'],
        matches: match['matches'] || []
      }
    end.compact
  end

  def load_bounty_repositories
    bounty_repos = []

    Dir.glob("#{@details_dir}*.json").each do |file|
      project_details = JSON.parse(File.read(file))
      assets = project_details.dig('pageProps', 'bounty', 'assets') || []

      assets.each do |asset|
        bounty_repos << asset['url'] if asset['url']&.include?('github.com')
      end
    rescue JSON::ParserError
      # Skip invalid JSON files
    end

    bounty_repos
  end

  def display_cross_referenced_results(github_results, bounty_repos, verbose = false)
    matches_found = false

    github_results.each do |result|
      # Check if this repository matches any bounty repository
      # Handle cases where bounty URLs include paths/branches (e.g., /tree/master/src)
      matching_bounty = bounty_repos.find do |bounty_url|
        # Extract base repo URL from bounty URL for GitHub repositories
        if bounty_url.include?('github.com')
          bounty_base = bounty_url.match(%r{(https://github\.com/[^/]+/[^/]+)})&.[](1)
          bounty_base == result[:repo_url]
        else
          # For non-GitHub URLs, use the original logic
          bounty_url.start_with?(result[:repo_url])
        end
      end

      next unless matching_bounty

      matches_found = true

      puts '=' * 60
      puts "🎯 BOUNTY MATCH: #{result[:full_name]} (#{result[:language].upcase})"
      puts "File: #{result[:filepath]}"
      puts "GitHub: #{result[:file_url]}"

      if verbose
        puts "Description: #{result[:description]}" if result[:description]
        puts "Bounty Asset: #{matching_bounty}"
        puts '-' * 40

        result[:text_matches].each_with_index do |match, index|
          puts "Match #{index + 1}:"

          if match[:matches] && !match[:matches].empty?
            puts 'Matched text:'
            match[:matches].each do |text_match|
              puts "  - \"#{text_match['text']}\""
            end
          end

          puts 'Code fragment:'
          puts "```#{result[:language]}"
          puts match[:fragment]
          puts '```'
          puts
        end
      else
        # Show just the count of matches in non-verbose mode
        match_count = result[:text_matches].length
        puts "Matches: #{match_count}"
      end
      puts
    end

    return if matches_found

    puts 'No matches found between GitHub search results and Immunefi bounty repositories.'
    puts 'This could mean:'
    puts "- The search term doesn't exist in any bounty repositories"
    puts "- The repositories containing the search term don't have active bounties"
    puts "- The search term exists but not in the target languages (#{TARGET_LANGUAGES.join(', ')})"
    puts "- The search term exists but too many results from irrelevant repositories are returned by GitHub search"
  end

  def format_currency(amount)
    return 'N/A' unless amount

    amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end

# Command line interface
def main
  options = {}

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"
    opts.separator ''
    opts.separator 'Modes:'
    opts.on('-l', '--list', 'List all qualifying Immunefi bounties (default)') do
      options[:mode] = :list
    end
    opts.on('-s', '--search QUERY', 'Search GitHub for code patterns and cross-reference with bounties') do |query|
      options[:mode] = :search
      options[:query] = query
    end
    opts.separator ''
    opts.separator 'Options:'
    opts.on('-v', '--verbose', 'Show detailed asset information in list mode') do
      options[:verbose] = true
    end
    opts.on('-h', '--help', 'Show this help message') do
      puts opts
      exit
    end
  end.parse!

  # Default to list mode if no mode specified
  options[:mode] ||= :list

  searcher = ImmuneFiSearch.new

  case options[:mode]
  when :list
    searcher.run_list_mode(options[:verbose])
  when :search
    if options[:query].nil? || options[:query].strip.empty?
      puts 'Error: Search query is required for search mode'
      puts "Usage: #{$0} --search 'your search term'"
      exit 1
    end
    searcher.run_search_mode(options[:query])
  end
end

main if __FILE__ == $0
