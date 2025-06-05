# GitHub Repository Scraper

A Ruby application for scraping GitHub repositories, pull requests, and reviews.

## Setup

1. Clone this repository
2. Install dependencies with `bundle install`
3. Create a `.env` file with your GitHub access token:
   ```
   GITHUB_ACCESS_TOKEN=your_token_here
   ```
4. Run the scraper: `ruby scraper.rb`

## Configuration

You can configure which organization to scrape by changing the `ORGANIZATION` constant in `scraper.rb`.

## Features

- Fetches repositories for an organization
- Fetches pull requests for each repository
- Fetches reviews for each pull request
- Stores all data in SQLite database
- Handles rate limiting and retries automatically

## License

MIT