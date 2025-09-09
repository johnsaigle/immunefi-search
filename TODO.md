Do the per-repo search if no results in the first place
- should already exist in local opencode session (laptop)

```
## Proposed Enhancement

     Two-Phase Search Approach:

     Phase 1: Global Search (Current)

     • Search across all GitHub using search/code API
     • Cross-reference with Immunefi bounty repositories

     Phase 2: Targeted Repository Search (New Fallback)

     • If Phase 1 yields no matches, query individual bounty repositories
     • Use GitHub's repository-specific search: GET /repos/{owner}/{repo}/search/code

     ### Implementation Strategy

     1. Extract Repository List: From bounty URLs, build list of unique owner/repo pairs
     2. Repository-Specific Search: Query each repo individually for the search pattern
     3. Language Filtering: Only search repos that match our target languages
```
