#!/usr/bin/env ruby
# frozen_string_literal: true

# test_github_client.rb
# @author Josh Trujillo

require 'rubygems'
require 'bundler/setup'
Bundler.require
require_relative 'lib/github_client'
require 'dotenv/load'

# Create a new client instance
client = GitHubClient.new

# Check rate limit status
rate_limit = client.rate_limit_status
puts "Rate limit: #{rate_limit.limit}"
puts "Remaining: #{rate_limit.remaining}"
puts "Resets at: #{Time.at(rate_limit.resets_at)}"

# Test fetching repositories
begin
  repos = client.fetch_organization_repos('vercel')
  puts "\nFetched #{repos.size} repositories from Vercel:"

  # Display first 5 repos
  repos.first(5).each do |repo|
    puts "- #{repo.name}: #{repo.html_url}"
  end

  # Test fetching pull requests for the first repository
  if repos.any?
    first_repo = repos.first
    repo_full_name = "vercel/#{first_repo.name}"

    pulls = client.fetch_pull_requests(repo_full_name)
    puts "\nFetched #{pulls.size} pull requests from #{repo_full_name}"

    # Display first 3 pull requests
    pulls.first(3).each do |pull|
      puts "- ##{pull.number}: #{pull.title} by #{pull.user.login}"

      # Test fetching reviews for this pull request
      reviews = client.fetch_pull_request_reviews(repo_full_name, pull.number)
      puts " - Has #{reviews.size} reviews"
    end
  end
rescue StandardError => e
  puts "Error: #{e.message}"
end
