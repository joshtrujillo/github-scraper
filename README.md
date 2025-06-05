# GitHub Repository Scraper

A Ruby application for scraping GitHub repositories, pull requests, and reviews.

## Setup

1. Clone this repository
2. Install dependencies with `bundle install`
3. Create a `.env` file with your GitHub access token:
   ```
   GITHUB_ACCESS_TOKEN=your_token_here
   ```
4. Run the scraper:
   ```bash
   # Incremental sync (default) - only fetches data that's changed since last run
   ruby scraper.rb
   
   # Full sync - fetches all data regardless of last sync time
   ruby scraper.rb --full
   
   # Show help
   ruby scraper.rb --help
   ```

## Configuration

You can configure which organization to scrape by changing the `ORGANIZATION` constant in `scraper.rb`.

## Features

- Fetches repositories for an organization
- Fetches pull requests for each repository
- Fetches reviews for each pull request
- Stores all data in SQLite database
- Handles rate limiting and retries automatically
- Supports incremental updates to minimize API requests
- Implements in-memory caching to reduce duplicate requests

## Incremental Updates

The scraper tracks the last time each repository and pull request was synced. 
On subsequent runs, it only fetches data that has been updated since the last sync.
This significantly reduces API calls and helps stay within GitHub's rate limits.

To perform a full sync that ignores previous sync timestamps, use the `--full` flag.

## License

GPL
