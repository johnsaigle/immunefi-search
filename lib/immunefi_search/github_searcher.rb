require 'net/http'
require 'json'
require_relative 'config'
require_relative 'rate_limiter'

module ImmuneFiSearch
  class GitHubSearcher
    def initialize
      @rate_limiter = RateLimiter.new
    end

    def global_search(query, token)
      github_results = []

      ImmuneFiSearch::GITHUB_SEARCH_LANGUAGES.each_with_index do |lang, index|
        puts "Searching #{lang.upcase} repositories... (#{index + 1}/#{ImmuneFiSearch::GITHUB_SEARCH_LANGUAGES.length})"

        results = search_github_by_language(query, lang, token)
        github_results += parse_github_results(results, lang) if results

        # Add delay between requests to be respectful to the API
        @rate_limiter.api_delay if index < ImmuneFiSearch::GITHUB_SEARCH_LANGUAGES.length - 1
      end

      puts "GitHub search completed. Found #{github_results.length} total results."
      github_results
    end

    def search_repository(query, owner, repo, token)
      # Use GitHub's global code search API with repo qualifier
      search_query = "#{query} repo:#{owner}/#{repo}"
      encoded_query = URI.encode_www_form_component(search_query)
      uri = URI("https://api.github.com/search/code?q=#{encoded_query}")

      req = Net::HTTP::Get.new(uri)
      req['Accept'] = 'application/vnd.github.v3.text-match+json'
      req['Authorization'] = "Bearer #{token}"

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        res = http.request(req)

        case res.code
        when '200'
          results = JSON.parse(res.body)
          parse_repository_search_results(results, owner, repo)
        when '403'
          if res['X-RateLimit-Remaining']&.to_i == 0
            puts "⚠️ Rate limited - remaining: #{res['X-RateLimit-Remaining']}, reset at: #{Time.at(res['X-RateLimit-Reset'].to_i)}"
            return nil # Signal rate limit hit
          else
            puts '⚠️ Access forbidden (403) - may be private repo or insufficient permissions'
            return [] # Access denied but continue
          end
        when '404'
          puts "⚠️ Repository #{owner}/#{repo} not found (404)"
          return []
        when '422'
          puts '⚠️ Search query invalid or too complex (422)'
          return []
        else
          puts "⚠️ GitHub API error: #{res.code} #{res.message}"
          puts "Response body: #{res.body[0..200]}..." if res.body
          return [] # Other errors but continue
        end
      end
    rescue StandardError => e
      puts "⚠️ Network error searching #{owner}/#{repo}: #{e.message}"
      [] # Network errors but continue
    end

    def search_single_repository(query, repo_spec, token)
      owner, repo = repo_spec.split('/', 2)
      puts "Searching repository #{owner}/#{repo} for: #{query}"
      puts "API endpoint: https://api.github.com/search/code?q=#{query} repo:#{owner}/#{repo}"
      puts ''

      results = search_repository(query, owner, repo, token)

      if results.nil?
        puts '⚠️ Search failed due to rate limiting'
        []
      elsif results.empty?
        puts '❌ No matches found (or search failed - see warnings above)'
        []
      else
        puts "✅ Found #{results.length} matches"
        results
      end
    end

    def search_high_value_repositories(query, token, high_value_repos)
      puts "Searching #{high_value_repos.length} high-value bounty repositories (sorted by bounty size)"
      puts ''

      results = []

      high_value_repos.each_with_index do |repo_info, index|
        owner = repo_info[:owner]
        repo = repo_info[:repo]
        bounty_amount = repo_info[:bounty_amount]
        project_name = repo_info[:project_name]

        print "#{index + 1}. Searching #{owner}/#{repo} ($#{format_currency(bounty_amount)} - #{project_name})... "

        repo_results = search_repository(query, owner, repo, token)

        if repo_results.nil?
          puts '⚠️ Rate limited - stopping'
          break
        elsif repo_results.empty?
          puts '❌ No matches'
        else
          puts "✅ Found #{repo_results.length} matches"
          results.concat(repo_results)
        end

        @rate_limiter.repository_delay if index < high_value_repos.length - 1
      end

      puts ''
      puts "Phase 2 completed. Found #{results.length} total matches in high-value repositories."
      results
    end

    private

    def search_github_by_language(query, language, token)
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
          @rate_limiter.handle_rate_limit(res, language)
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

    def parse_repository_search_results(results, owner, repo)
      return [] unless results['items']

      results['items'].map do |item|
        {
          filename: item['name'],
          filepath: item['path'],
          file_url: item['html_url'],
          sha: item['sha'],
          repo_url: "https://github.com/#{owner}/#{repo}",
          full_name: "#{owner}/#{repo}",
          description: nil,
          language: item['language'] || 'unknown',
          text_matches: extract_text_matches(item['text_matches'] || []),
          matching_bounty: "Found in high-value bounty repository #{owner}/#{repo}"
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

    def format_currency(amount)
      return 'N/A' unless amount

      amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end
  end
end
