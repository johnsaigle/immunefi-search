require 'net/http'
require 'json'
require_relative 'config'

module ImmuneFiSearch
  class RateLimiter
    def check_rate_limit_status(token)
      uri = URI('https://api.github.com/rate_limit')
      req = Net::HTTP::Get.new(uri)
      req['Authorization'] = "Bearer #{token}"

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        res = http.request(req)
        if res.code == '200'
          rate_info = JSON.parse(res.body)
          search_limit = rate_info.dig('resources', 'search')

          display_rate_limit_status(search_limit) if search_limit
        end
      end
    rescue StandardError => e
      puts "Note: Could not check GitHub rate limit status (#{e.message})"
    end

    def handle_rate_limit(response, language)
      rate_limit_remaining = response['X-RateLimit-Remaining']&.to_i
      rate_limit_reset = response['X-RateLimit-Reset']&.to_i

      if rate_limit_remaining == 0 && rate_limit_reset
        display_rate_limit_exceeded(rate_limit_reset, language)
      elsif response.body&.include?('rate limit')
        puts "⚠️  GitHub API rate limit exceeded for #{language} searches"
        puts "   Response: #{response.body}"
      else
        puts "GitHub API 403 error for #{language}: #{response.message}"
      end
    end

    def wait_for_rate_limit_reset(reset_time, context = 'API')
      wait_seconds = [reset_time - Time.now.to_i, 0].max
      wait_minutes = (wait_seconds / 60.0).ceil

      puts '⚠️ Rate limited - waiting for reset...'
      puts "   Reset at: #{Time.at(reset_time).strftime('%H:%M:%S')}"
      puts "   Wait time: ~#{wait_minutes} minutes"
      puts "   Context: #{context}"
      puts ''

      return unless wait_seconds > 0

      puts "⏳ Sleeping for #{wait_seconds} seconds..."
      sleep(wait_seconds + 5) # Add 5 second buffer
      puts '✅ Rate limit reset - resuming search...'
    end

    def exponential_backoff(attempt, max_attempts = 5, base_delay = 2)
      return false if attempt >= max_attempts

      delay = base_delay * (2**attempt) + rand(1..5) # Add jitter
      puts "⚠️ Rate limited - exponential backoff (attempt #{attempt + 1}/#{max_attempts})"
      puts "   Waiting #{delay} seconds before retry..."
      sleep(delay)
      true
    end

    def api_delay
      sleep(ImmuneFiSearch::API_REQUEST_DELAY)
    end

    def repository_delay
      sleep(ImmuneFiSearch::REPOSITORY_SEARCH_DELAY)
    end

    private

    def display_rate_limit_status(search_limit)
      remaining = search_limit['remaining']
      limit = search_limit['limit']
      reset_time = Time.at(search_limit['reset'])

      puts "GitHub API Status: #{remaining}/#{limit} search requests remaining"

      return unless remaining < ImmuneFiSearch::GITHUB_SEARCH_LANGUAGES.length

      puts "⚠️  Warning: Low rate limit remaining. Reset at #{reset_time.strftime('%H:%M:%S')}"
    end

    def display_rate_limit_exceeded(rate_limit_reset, language)
      reset_time = Time.at(rate_limit_reset)
      wait_minutes = ((reset_time - Time.now) / 60).ceil

      puts "⚠️  GitHub API rate limit exceeded for #{language} searches"
      puts "   Rate limit will reset at: #{reset_time.strftime('%H:%M:%S')}"
      puts "   Wait time: ~#{wait_minutes} minutes"

      if ENV['GITHUB_TOKEN']&.start_with?('ghp_')
        puts '   ✓ Using Personal Access Token (higher rate limits should apply)'
      else
        puts '   ⚠️  Consider using a GitHub Personal Access Token for higher rate limits'
      end
    end
  end
end
