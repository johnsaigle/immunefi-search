require 'net/http'
require 'json'
require 'fileutils'
require_relative 'config'

module ImmuneFiSearch
  class BountyManager
    def initialize
      @date = Time.now.strftime('%Y-%m-%d')
      @project_file = "data/projects-#{@date}.json"
      @details_dir = 'data/project-details/'

      FileUtils.mkdir_p(@details_dir) unless Dir.exist?(@details_dir)
    end

    def fetch_projects
      if File.exist?(@project_file)
        JSON.parse(File.read(@project_file))
      else
        fetch_projects_from_api
      end
    end

    def fetch_project_details(project_id)
      project_details_file = "#{@details_dir}#{project_id}.json"

      if File.exist?(project_details_file)
        JSON.parse(File.read(project_details_file))
      else
        fetch_project_details_from_api(project_id)
      end
    rescue JSON::ParserError
      nil
    end

    def filter_projects_by_criteria(projects)
      matching_projects = []

      projects.each do |program|
        # Check if program uses any of our target languages
        program_languages = program['tags']['language'].map(&:downcase)
        language_match = ImmuneFiSearch::TARGET_LANGUAGES.any? { |lang| program_languages.include?(lang) }
        next unless language_match

        # Fetch project details
        project_details = fetch_project_details(program['id'])
        next unless project_details

        # Check bounty criteria
        target_rewards = project_details.dig('pageProps', 'bounty', 'rewards')&.select do |reward|
          %w[blockchain_dlt smart_contract].include?(reward['assetType']) &&
            reward['maxReward'] && reward['maxReward'] > ImmuneFiSearch::MIN_BOUNTY
        end
        next if target_rewards.nil? || target_rewards.empty?

        matching_projects << {
          program: program,
          project_details: project_details,
          target_rewards: target_rewards,
          program_languages: program_languages
        }
      end

      matching_projects
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

    def get_high_value_projects_sorted(projects)
      high_value_projects = []

      projects.each do |program|
        # Check if program uses any of our target languages
        program_languages = program['tags']['language'].map(&:downcase)
        language_match = ImmuneFiSearch::TARGET_LANGUAGES.any? { |lang| program_languages.include?(lang) }
        next unless language_match

        # Fetch project details
        project_details = fetch_project_details(program['id'])
        next unless project_details

        # Check bounty criteria and get max bounty
        max_bounty = project_details.dig('pageProps', 'bounty', 'maxBounty')
        next unless max_bounty && max_bounty > ImmuneFiSearch::MIN_BOUNTY

        high_value_projects << {
          program: program,
          project_details: project_details,
          max_bounty: max_bounty
        }
      end

      # Sort by bounty amount (highest first)
      high_value_projects.sort_by { |p| -p[:max_bounty] }
    end

    private

    def fetch_projects_from_api
      puts 'Fetching projects from Immunefi...'
      uri = URI(ImmuneFiSearch::PROGRAMS_URL)
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
        req = Net::HTTP::Get.new(uri)
        res = http.request req
        raise "HTTP Error: #{res.code} #{res.message}" unless res.code == '200'

        projects = JSON.parse(res.body)
        File.write(@project_file, JSON.pretty_generate(projects))
        projects
      end
    end

    def fetch_project_details_from_api(project_id)
      project_uri = URI("https://raw.githubusercontent.com/infosec-us-team/Immunefi-Bug-Bounty-Programs-Unofficial/main/project/#{project_id}.json")
      Net::HTTP.start(project_uri.hostname, project_uri.port, use_ssl: project_uri.scheme == 'https') do |http|
        req = Net::HTTP::Get.new(project_uri)
        res = http.request req
        return nil unless res.code == '200'

        project_details = JSON.parse(res.body)
        File.write("#{@details_dir}#{project_id}.json", JSON.pretty_generate(project_details))
        project_details
      end
    end
  end
end
