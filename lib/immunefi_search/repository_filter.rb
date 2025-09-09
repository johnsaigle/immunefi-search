require 'set'
require_relative 'config'

module ImmuneFiSearch
  class RepositoryFilter
    def extract_github_repositories(bounty_urls)
      github_repos = Set.new

      bounty_urls.each do |url|
        next unless url.include?('github.com') && !url.include?('gist.github.com')

        # Skip non-repository URLs
        next if url.include?('/releases/') || url.include?('/issues/') || url.include?('/wiki/')

        # Extract base repository from various GitHub URL formats
        match = url.match(%r{https://github\.com/([^/]+)/([^/]+)})
        next unless match

        owner = match[1]
        repo = match[2]

        # Skip obvious non-repository paths
        next if repo.include?('#') || repo.include?('?') || repo == 'tree' || repo == 'blob'

        github_repos.add([owner, repo]) if accessible_repo?(owner, repo)
      end

      github_repos.to_a
    end

    def extract_repositories_from_high_value_projects(high_value_projects)
      high_value_repos = []

      high_value_projects.each do |project_info|
        project_details = project_info[:project_details]
        max_bounty = project_info[:max_bounty]
        project_name = project_info[:program]['project']

        # Extract GitHub repositories from this project's assets
        assets = project_details.dig('pageProps', 'bounty', 'assets') || []
        github_repos = extract_accessible_repos_from_assets(assets)

        github_repos.each do |owner, repo|
          high_value_repos << {
            owner: owner,
            repo: repo,
            bounty_amount: max_bounty,
            project_name: project_name
          }
        end
      end

      # Remove duplicates and sort by bounty amount
      unique_repos = high_value_repos.uniq { |r| [r[:owner], r[:repo]] }
      unique_repos.sort_by { |r| -r[:bounty_amount] }
    end

    def find_cross_referenced_results(github_results, bounty_repos)
      cross_referenced = []

      github_results.each do |result|
        matching_bounty = bounty_repos.find do |bounty_url|
          if bounty_url.include?('github.com')
            bounty_base = bounty_url.match(%r{(https://github\.com/[^/]+/[^/]+)})&.[](1)
            bounty_base == result[:repo_url]
          else
            bounty_url.start_with?(result[:repo_url])
          end
        end

        if matching_bounty
          result[:matching_bounty] = matching_bounty
          cross_referenced << result
        end
      end

      cross_referenced
    end

    def accessible_repo?(owner, _repo)
      # Well-known public organizations that are likely accessible
      ImmuneFiSearch::ACCESSIBLE_ORGS.include?(owner.downcase) ||
        owner.downcase.include?('wormhole') ||
        owner.downcase.include?('layerzero') ||
        owner.downcase.include?('defi') ||
        owner.downcase.include?('protocol')
    end

    private

    def extract_accessible_repos_from_assets(assets)
      github_repos = Set.new

      assets.each do |asset|
        url = asset['url']
        next unless url&.include?('github.com')
        next if url.include?('gist.github.com')

        # Extract owner/repo from various GitHub URL formats
        match = url.match(%r{https://github\.com/([^/]+)/([^/]+)})
        next unless match

        owner = match[1]
        repo = match[2]

        # Filter to known accessible repositories
        github_repos.add([owner, repo]) if accessible_repo?(owner, repo)
      end

      github_repos.to_a
    end
  end
end
