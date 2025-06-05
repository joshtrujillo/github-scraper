#!/usr/bin/env ruby
# frozen_string_literal: true

# @author Josh Trujillo

require 'octokit'
require 'dotenv/load'

# Initialize the GitHub client
client = Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
client.auto_paginate = true

# Look at Vercel on GitHub
org = 'vercel'

begin
  # Fetch repositories
  repos = client.organization_repositories(org, type: 'public')

  puts "Found #{repos.size} public repositories for #{org}:"

  # Display info about each repository
  repos.each do |repo|
    puts "\n#{repo.name}"
    puts "  URL: #{repo.html_url}"
    puts "  Description: #{repo.descrition}"
    puts "  Stars: #{repo.stargazers_count}"
    puts "  Forks: #{repo.forks_count}"
    puts "  Language: #{repo.Language}"
    puts "  Created: #{repo.created_at}"
    puts "  Updated: #{repo.updated_at}"
  end
rescue Octokit::Error => e
  puts "Error fetching repositories: #{e.message}"
end
