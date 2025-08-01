#!/usr/bin/env ruby
# Purpose: Search for Immunefi Bug Bounty Programs by language and filter for blockchain_dlt type
require 'net/http'
require 'json'
require 'fileutils'

# Immunefi Bug Bounty Programs details
PROGRAMS_URL = 'https://raw.githubusercontent.com/infosec-us-team/Immunefi-Bug-Bounty-Programs-Unofficial/main/projects.json'
uri = URI(PROGRAMS_URL)

puts "Immunefi search by language"
puts "> Enter the language you want to search for"
query = gets.chomp
puts ""

date = Time.now.strftime("%Y-%m-%d")
PROJECT_FILE = "data/projects-#{date}.json"
DETAILS_DIR = "data/project-details/"

FileUtils.mkdir_p(DETAILS_DIR) unless Dir.exist?(DETAILS_DIR)

if File.exist?(PROJECT_FILE)
    puts "Projects file already exists, skipping search"
    projects = JSON.parse(File.read(PROJECT_FILE))
else
    puts "Fetching projects from Immunefi"
    Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http| 
        req = Net::HTTP::Get.new(uri)
        res = http.request req

        raise "HTTP Error: #{res.code} #{res.message}" unless res.code == "200"

        projects = JSON.parse(res.body)
        File.write(PROJECT_FILE, JSON.pretty_generate(projects))
    end
end

projects.each do |program|
    if program['tags']['language'].map(&:downcase).include?(query.downcase)
        puts program['project']
        puts "https://immunefi.com/bounty/#{program['id']}"

        project_details_file = "data/project-details/#{program['id']}.json"
        if File.exist?(project_details_file)
            puts "Projects details file for #{program['id']} already exists, skipping search"
            project_details = JSON.parse(File.read(project_details_file))
        else
            project_uri = URI("https://raw.githubusercontent.com/infosec-us-team/Immunefi-Bug-Bounty-Programs-Unofficial/main/project/#{program['id']}.json")
            Net::HTTP.start(project_uri.hostname, project_uri.port, :use_ssl => project_uri.scheme == 'https') do |http| 
                req = Net::HTTP::Get.new(project_uri)
                res = http.request req
                puts "project error" && exit unless res.code == "200"
                project_details = JSON.parse(res.body)
                File.write(project_details_file, JSON.pretty_generate(project_details))
            end
        end

        project_details.dig('pageProps', 'bounty', 'assets').each do |asset|
            next unless asset['type'] == 'blockchain_dlt'

            puts "- Asset"
            puts "-- Description: #{asset['description']}"
            puts "-- Type: #{asset['type']}"
            puts "-- URL: #{asset['url']}"
            puts ""
        end
    end
end
