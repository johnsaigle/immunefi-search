require 'json'
require 'fileutils'
require 'digest'

module ImmuneFiSearch
  class SearchCache
    CACHE_DIR = 'data/search_cache'

    def initialize
      FileUtils.mkdir_p(CACHE_DIR)
    end

    def cache_key(query, repo_list, language = nil, exact = false)
      # Create a unique cache key based on search parameters
      key_data = {
        query: query,
        language: language,
        exact: exact,
        repo_list_hash: Digest::MD5.hexdigest(repo_list.map { |r| "#{r[:owner]}/#{r[:repo]}" }.sort.join(','))
      }
      Digest::MD5.hexdigest(key_data.to_json)
    end

    def load_progress(cache_key)
      progress_file = File.join(CACHE_DIR, "#{cache_key}_progress.json")
      return { completed_repos: [], results: [] } unless File.exist?(progress_file)

      JSON.parse(File.read(progress_file), symbolize_names: true)
    rescue StandardError => e
      puts "⚠️ Warning: Could not load search progress cache: #{e.message}"
      { completed_repos: [], results: [] }
    end

    def save_progress(cache_key, completed_repos, accumulated_results)
      progress_file = File.join(CACHE_DIR, "#{cache_key}_progress.json")
      progress_data = {
        completed_repos: completed_repos,
        results: accumulated_results,
        last_updated: Time.now.iso8601,
        total_results: accumulated_results.length
      }

      File.write(progress_file, JSON.pretty_generate(progress_data))
    rescue StandardError => e
      puts "⚠️ Warning: Could not save search progress: #{e.message}"
    end

    def cleanup_cache(cache_key)
      progress_file = File.join(CACHE_DIR, "#{cache_key}_progress.json")
      File.delete(progress_file) if File.exist?(progress_file)
    rescue StandardError => e
      puts "⚠️ Warning: Could not cleanup cache: #{e.message}"
    end

    def cache_results(cache_key, final_results)
      results_file = File.join(CACHE_DIR, "#{cache_key}_results.json")
      cache_data = {
        results: final_results,
        cached_at: Time.now.iso8601,
        total_results: final_results.length
      }

      File.write(results_file, JSON.pretty_generate(cache_data))
    rescue StandardError => e
      puts "⚠️ Warning: Could not cache final results: #{e.message}"
    end

    def load_cached_results(cache_key, max_age_hours = 24)
      results_file = File.join(CACHE_DIR, "#{cache_key}_results.json")
      return nil unless File.exist?(results_file)

      cache_data = JSON.parse(File.read(results_file), symbolize_names: true)
      cached_at = Time.parse(cache_data[:cached_at])

      if Time.now - cached_at < (max_age_hours * 3600)
        puts "✅ Using cached results from #{cached_at.strftime('%H:%M:%S')} (#{cache_data[:total_results]} results)"
        cache_data[:results]
      else
        puts "⚠️ Cached results are stale (#{((Time.now - cached_at) / 3600).round(1)}h old) - searching fresh"
        nil
      end
    rescue StandardError => e
      puts "⚠️ Warning: Could not load cached results: #{e.message}"
      nil
    end
  end
end
