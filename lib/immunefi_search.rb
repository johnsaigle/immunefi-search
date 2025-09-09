require_relative 'immunefi_search/config'
require_relative 'immunefi_search/bounty_manager'
require_relative 'immunefi_search/github_searcher'
require_relative 'immunefi_search/repository_filter'
require_relative 'immunefi_search/rate_limiter'
require_relative 'immunefi_search/result_formatter'

module ImmuneFiSearch
  class Application
    def initialize
      @bounty_manager = BountyManager.new
      @github_searcher = GitHubSearcher.new
      @repository_filter = RepositoryFilter.new
      @rate_limiter = RateLimiter.new
      @formatter = ResultFormatter.new
    end

    def run_list_mode(verbose = false)
      puts "Immunefi search for #{TARGET_LANGUAGES.join(', ').upcase} programs"
      puts 'Filtering for blockchain/DLT and smart contract bounties >$100k'
      puts ''

      projects = @bounty_manager.fetch_projects
      matching_projects = @bounty_manager.filter_projects_by_criteria(projects)

      matching_projects.each do |project_info|
        @formatter.display_project(
          project_info[:program],
          project_info[:project_details],
          project_info[:target_rewards],
          project_info[:program_languages],
          verbose
        )
      end
    end

    def run_search_mode(query, repo = nil, full = false)
      token = ENV['GITHUB_TOKEN']

      if repo
        run_single_repository_search(query, repo, token)
      elsif full
        run_full_search(query, token)
      else
        run_multi_phase_search(query, token)
      end
    end

    private

    def run_single_repository_search(query, repo, token)
      # Check rate limit status
      @rate_limiter.check_rate_limit_status(token)
      puts ''

      results = @github_searcher.search_single_repository(query, repo, token)
      @formatter.display_search_results(results)
    end

    def run_multi_phase_search(query, token)
      puts "Searching GitHub for: #{query}"
      puts 'Cross-referencing with Immunefi bounties...'

      # Check rate limit status
      @rate_limiter.check_rate_limit_status(token)
      puts ''

      # Phase 1: Global search
      github_results = @github_searcher.global_search(query, token)
      bounty_repos = @bounty_manager.load_bounty_repositories
      cross_referenced_results = @repository_filter.find_cross_referenced_results(github_results, bounty_repos)

      if cross_referenced_results.empty?
        run_phase_2_search(query, token)
      else
        puts "Phase 1 (global search) found #{cross_referenced_results.length} cross-referenced results:"
        puts ''
        @formatter.display_search_results(cross_referenced_results)
      end
    end

    def run_full_search(query, token)
      puts "Running comprehensive search for: #{query}"
      puts 'This will search both globally and through all high-value bounty repositories...'
      puts ''

      # Check rate limit status
      @rate_limiter.check_rate_limit_status(token)
      puts ''

      all_results = []

      # Phase 1: Global search
      puts '=== PHASE 1: GLOBAL SEARCH ==='
      github_results = @github_searcher.global_search(query, token)
      bounty_repos = @bounty_manager.load_bounty_repositories
      cross_referenced_results = @repository_filter.find_cross_referenced_results(github_results, bounty_repos)

      if cross_referenced_results.any?
        puts "Phase 1 found #{cross_referenced_results.length} cross-referenced results:"
        puts ''
        @formatter.display_search_results(cross_referenced_results)
        all_results.concat(cross_referenced_results)
        puts ''
        puts '=' * 60
        puts ''
      else
        puts 'Phase 1 (global search) found no cross-referenced results.'
        puts ''
      end

      # Phase 2: High-value repository search (always run in full mode)
      puts '=== PHASE 2: HIGH-VALUE BOUNTY REPOSITORIES ==='
      phase2_results = run_phase_2_search_internal(query, token)
      all_results.concat(phase2_results)

      # Summary
      puts ''
      puts '=' * 60
      puts 'COMPREHENSIVE SEARCH COMPLETE'
      puts "Total results found: #{all_results.length}"
      puts "Phase 1 (Global): #{cross_referenced_results.length} results"
      puts "Phase 2 (High-value repos): #{phase2_results.length} results"
    end

    def run_phase_2_search(query, token)
      puts 'Phase 1 (global search) found no cross-referenced results.'
      puts 'Starting Phase 2: Searching high-value bounty repositories...'
      puts ''

      phase2_results = run_phase_2_search_internal(query, token)
      @formatter.display_search_results(phase2_results)
    end

    def run_phase_2_search_internal(query, token)
      # Get high-value projects sorted by bounty amount
      projects = @bounty_manager.fetch_projects
      high_value_projects = @bounty_manager.get_high_value_projects_sorted(projects)

      # Extract repositories from high-value projects
      high_value_repos = @repository_filter.extract_repositories_from_high_value_projects(high_value_projects)

      # Search individual repositories
      @github_searcher.search_high_value_repositories(query, token, high_value_repos)
    end
  end
end
