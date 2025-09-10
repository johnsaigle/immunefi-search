require 'net/http'
require 'json'
require_relative 'config'
require_relative 'rate_limiter'

module ImmuneFiSearch
  class GitHubSearcher
    def initialize
      @rate_limiter = RateLimiter.new
    end

    def global_search(query, token, language = nil)
      github_results = []

      # If language filter is specified, only search that language
      languages_to_search = if language && ImmuneFiSearch::GITHUB_SEARCH_LANGUAGES.include?(language.downcase)
                              [language.downcase]
                            else
                              ImmuneFiSearch::GITHUB_SEARCH_LANGUAGES
                            end

      if language && !ImmuneFiSearch::GITHUB_SEARCH_LANGUAGES.include?(language.downcase)
        puts "Warning: Language '#{language}' not supported for global search (GitHub API limitation)"
        puts "Supported languages for global search: #{ImmuneFiSearch::GITHUB_SEARCH_LANGUAGES.join(', ')}"
        return []
      end

      languages_to_search.each_with_index do |lang, index|
        puts "Searching #{lang.upcase} repositories... (#{index + 1}/#{languages_to_search.length})"

        results = search_github_by_language(query, lang, token)
        github_results += parse_github_results(results, lang) if results

        # Add delay between requests to be respectful to the API
        @rate_limiter.api_delay if index < languages_to_search.length - 1
      end

      puts "GitHub search completed. Found #{github_results.length} total results."
      github_results
    end

    def search_repository(query, owner, repo, token, language = nil)
      # Use GitHub's global code search API with repo qualifier
      search_query = "#{query} repo:#{owner}/#{repo}"
      search_query += " language:#{language}" if language
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

    def fetch_organization_repositories(org, token)
      puts "Fetching repositories from #{org} organization..."
      repos = []
      page = 1

      loop do
        uri = URI("https://api.github.com/orgs/#{org}/repos?per_page=100&page=#{page}&sort=updated")
        req = Net::HTTP::Get.new(uri)
        req['Accept'] = 'application/vnd.github+json'
        req['Authorization'] = "Bearer #{token}"

        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          res = http.request(req)

          case res.code
          when '200'
            page_repos = JSON.parse(res.body)
            return repos if page_repos.empty? # No more pages

            page_repos.each do |repo|
              repos << {
                name: repo['name'],
                language: repo['language'],
                private: repo['private'],
                archived: repo['archived']
              }
            end

            page += 1
            @rate_limiter.api_delay # Be respectful to API
          when '404'
            puts "⚠️ Organization #{org} not found or not accessible"
            return []
          when '403'
            if res['X-RateLimit-Remaining']&.to_i == 0
              puts '⚠️ Rate limited while fetching org repos'
              return []
            else
              puts "⚠️ Access forbidden to #{org} organization"
              return []
            end
          else
            puts "⚠️ Error fetching org repos: #{res.code} #{res.message}"
            return []
          end
        end
      end

      # Filter out private and archived repos
      accessible_repos = repos.reject { |repo| repo[:private] || repo[:archived] }
      puts "Filtered to #{accessible_repos.length} public, non-archived repositories"
      accessible_repos
    rescue StandardError => e
      puts "⚠️ Network error fetching organization repositories: #{e.message}"
      []
    end

    def search_single_repository(query, repo_spec, token, language = nil)
      owner, repo = repo_spec.split('/', 2)
      language_filter = language ? " language:#{language}" : ''
      puts "Searching repository #{owner}/#{repo} for: #{query}#{language_filter}"
      puts "API endpoint: https://api.github.com/search/code?q=#{query}#{language_filter} repo:#{owner}/#{repo}"
      puts ''

      results = search_repository(query, owner, repo, token, language)

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

    def search_organization_repositories(query, org, token, language = nil)
      puts "Discovering repositories in #{org} organization..."

      # Get list of repositories in the organization
      org_repos = fetch_organization_repositories(org, token)

      if org_repos.empty?
        puts "❌ No accessible repositories found in #{org} organization"
        return []
      end

      language_filter = language ? " (#{language.upcase} only)" : ''
      puts "Found #{org_repos.length} repositories in #{org}#{language_filter}"
      puts ''

      all_results = []

      org_repos.each_with_index do |repo_info, index|
        repo_name = repo_info[:name]
        repo_language = repo_info[:language]

        # Skip repositories that don't match language filter
        if language && repo_language&.downcase != language.downcase
          puts "#{index + 1}. Skipping #{org}/#{repo_name} (#{repo_language || 'unknown'}) - language mismatch"
          next
        end

        print "#{index + 1}. Searching #{org}/#{repo_name} (#{repo_language || 'unknown'})... "

        repo_results = search_repository(query, org, repo_name, token, language)

        if repo_results.nil?
          puts '⚠️ Rate limited - stopping'
          break
        elsif repo_results.empty?
          puts '❌ No matches'
        else
          puts "✅ Found #{repo_results.length} matches"
          all_results.concat(repo_results)
        end

        @rate_limiter.repository_delay if index < org_repos.length - 1
      end

      puts ''
      puts "Organization search completed. Found #{all_results.length} total matches in #{org}."
      all_results
    end

    def search_high_value_repositories(query, token, high_value_repos, language = nil)
      language_msg = language ? " (#{language.upcase} only)" : ''
      puts "Searching #{high_value_repos.length} high-value bounty repositories (sorted by bounty size)#{language_msg}"
      puts ''

      results = []

      high_value_repos.each_with_index do |repo_info, index|
        owner = repo_info[:owner]
        repo = repo_info[:repo]
        bounty_amount = repo_info[:bounty_amount]
        project_name = repo_info[:project_name]

        print "#{index + 1}. Searching #{owner}/#{repo} ($#{format_currency(bounty_amount)} - #{project_name})... "

        repo_results = search_repository(query, owner, repo, token, language)

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
