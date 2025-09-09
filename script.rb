#!/usr/bin/env ruby
# Purpose: Search for Immunefi Bug Bounty Programs by language and filter for blockchain_dlt type
require 'net/http'
require 'json'
require 'fileutils'

# Immunefi Bug Bounty Programs details
PROGRAMS_URL = 'https://raw.githubusercontent.com/infosec-us-team/Immunefi-Bug-Bounty-Programs-Unofficial/main/projects.json'
uri = URI(PROGRAMS_URL)

TARGET_LANGUAGES = %w[go rust solidity move]
puts "Immunefi search for #{TARGET_LANGUAGES.join(', ').upcase} programs"
puts 'Filtering for blockchain/DLT and smart contract bounties >$100k'
puts ''

date = Time.now.strftime('%Y-%m-%d')
PROJECT_FILE = "data/projects-#{date}.json"
DETAILS_DIR = 'data/project-details/'

FileUtils.mkdir_p(DETAILS_DIR) unless Dir.exist?(DETAILS_DIR)

if File.exist?(PROJECT_FILE)
  projects = JSON.parse(File.read(PROJECT_FILE))
else
  puts 'Fetching projects from Immunefi...'
  Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
    req = Net::HTTP::Get.new(uri)
    res = http.request req

    raise "HTTP Error: #{res.code} #{res.message}" unless res.code == '200'

    projects = JSON.parse(res.body)
    File.write(PROJECT_FILE, JSON.pretty_generate(projects))
  end
end

projects.each do |program|
  # Check if program uses any of our target languages
  program_languages = program['tags']['language'].map(&:downcase)
  language_match = TARGET_LANGUAGES.any? { |lang| program_languages.include?(lang) }

  next unless language_match

  project_details_file = "data/project-details/#{program['id']}.json"
  if File.exist?(project_details_file)
    project_details = JSON.parse(File.read(project_details_file))
  else
    project_uri = URI("https://raw.githubusercontent.com/infosec-us-team/Immunefi-Bug-Bounty-Programs-Unofficial/main/project/#{program['id']}.json")
    Net::HTTP.start(project_uri.hostname, project_uri.port, use_ssl: project_uri.scheme == 'https') do |http|
      req = Net::HTTP::Get.new(project_uri)
      res = http.request req
      puts exit unless res.code == '200'
      project_details = JSON.parse(res.body)
      File.write(project_details_file, JSON.pretty_generate(project_details))
    end
  end

  # Check if this program has blockchain/DLT or smart contract bounties over $100k
  target_rewards = project_details.dig('pageProps', 'bounty', 'rewards')&.select do |reward|
    %w[blockchain_dlt smart_contract].include?(reward['assetType']) &&
      reward['maxReward'] && reward['maxReward'] > 100_000
  end

  next if target_rewards.nil? || target_rewards.empty?

  # Get matching languages for this project
  matching_languages = TARGET_LANGUAGES.select { |lang| program_languages.include?(lang) }
  language_display = matching_languages.map(&:upcase).join(', ')

  puts '=' * 60
  puts "PROJECT: #{program['project']} [#{language_display}]"
  puts "URL: https://immunefi.com/bounty/#{program['id']}"
  puts "Max Bounty: $#{project_details.dig('pageProps', 'bounty', 'maxBounty')&.to_s&.reverse&.gsub(
    /(\d{3})(?=\d)/, '\\1,'
  )&.reverse || 'N/A'}"
  puts '=' * 60

  puts "\nBOUNTIES:"
  target_rewards.each do |reward|
    asset_type_display = reward['assetType'] == 'blockchain_dlt' ? 'Blockchain/DLT' : 'Smart Contract'
    puts "  • #{asset_type_display}: $#{reward['minReward']&.to_s&.reverse&.gsub(/(\d{3})(?=\d)/,
                                                                                 '\\1,')&.reverse || '0'} - $#{reward['maxReward']&.to_s&.reverse&.gsub(/(\d{3})(?=\d)/,
                                                                                                                                                        '\\1,')&.reverse} (#{reward['severity']})"
  end

  puts "\nASSETS:"
  project_details.dig('pageProps', 'bounty', 'assets')&.each do |asset|
    next unless %w[blockchain_dlt smart_contract].include?(asset['type'])

    puts "  • #{asset['description']}"
    puts "    Type: #{asset['type']}"
    puts "    URL: #{asset['url']}"
    puts ''
  end
  puts ''

  project_details.dig('pageProps', 'bounty', 'assets')&.each do |asset|
    next unless %w[blockchain_dlt smart_contract].include?(asset['type'])

    # puts '- Asset'
    # puts "-- Description: #{asset['description']}"
    # puts "-- Type: #{asset['type']}"
    # puts "-- URL: #{asset['url']}"
    # puts ''
  end
end
