require_relative 'config'

module ImmuneFiSearch
  class ResultFormatter
    def display_project(program, project_details, target_rewards, program_languages, verbose = false)
      matching_languages = ImmuneFiSearch::TARGET_LANGUAGES.select { |lang| program_languages.include?(lang) }
      language_display = matching_languages.map(&:upcase).join(', ')

      if verbose
        display_verbose_project(program, project_details, target_rewards, language_display)
      else
        display_concise_project(program, project_details, language_display)
      end
    end

    def display_search_results(results)
      if results.empty?
        display_no_results_message
        return
      end

      results.each do |result|
        display_single_result(result)
      end
    end

    def format_currency(amount)
      return 'N/A' unless amount

      amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    private

    def display_verbose_project(program, project_details, target_rewards, language_display)
      puts '=' * 60
      puts "PROJECT: #{program['project']} [#{language_display}]"
      puts "URL: https://immunefi.com/bounty/#{program['id']}"
      puts "Max Bounty: $#{format_currency(project_details.dig('pageProps', 'bounty', 'maxBounty'))}"
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
    end

    def display_concise_project(program, project_details, language_display)
      max_bounty = format_currency(project_details.dig('pageProps', 'bounty', 'maxBounty'))
      asset_count = project_details.dig('pageProps', 'bounty', 'assets')&.count do |asset|
        %w[blockchain_dlt smart_contract].include?(asset['type'])
      end || 0

      puts "#{program['project']} [#{language_display}] - $#{max_bounty} (#{asset_count} assets)"
      puts "  https://immunefi.com/bounty/#{program['id']}"
      puts ''
    end

    def display_single_result(result)
      puts '=' * 60
      puts "🎯 BOUNTY MATCH: #{result[:full_name]} (#{result[:language].upcase})"
      puts "File: #{result[:filepath]}"
      puts "GitHub: #{result[:file_url]}"
      puts "Bounty: #{result[:matching_bounty]}" if result[:matching_bounty]
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
      puts
    end

    def display_no_results_message
      puts 'No matches found in bounty repositories.'
      puts 'This could mean:'
      puts "- The search term doesn't exist in any accessible bounty repositories"
      puts '- The search term uses different syntax or casing'
      puts "- The repositories don't contain the pattern in target languages (#{ImmuneFiSearch::TARGET_LANGUAGES.join(', ')})"
    end
  end
end
