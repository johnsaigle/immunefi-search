module ImmuneFiSearch
  # API Configuration
  PROGRAMS_URL = 'https://raw.githubusercontent.com/infosec-us-team/Immunefi-Bug-Bounty-Programs-Unofficial/main/projects.json'

  # Search Configuration
  TARGET_LANGUAGES = %w[go rust solidity move].freeze
  MIN_BOUNTY = 100_000

  # GitHub API Configuration
  GITHUB_SEARCH_LANGUAGES = # GitHub doesn't have Move language support yet
    TARGET_LANGUAGES.reject do |lang|
      lang == 'move'
    end.freeze
  # Rate Limiting
  API_REQUEST_DELAY = 1.0 # seconds between requests
  REPOSITORY_SEARCH_DELAY = 0.5 # seconds between repository searches

  # Well-known accessible GitHub organizations
  ACCESSIBLE_ORGS = %w[
    wormhole-foundation layerzero-labs makerdao reserve-protocol
    compound-finance aave ethereum openzeppelin uniswap sushiswap
    chainlink smartcontractkit balancer-labs yearn tranchess
    olympusdao frax-finance convex-finance curve-fi synthetixio
    aavegotchi immutable-holdings swapr-org bgd-labs
    lidofinance rocket-pool stakewise trusttoken
  ].freeze
end
