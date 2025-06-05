#!/usr/bin/env ruby
# frozen_string_literal: true

# test_setup.rb
# @author Josh Trujillo
require_relative 'config/database'
require_relative 'models/repository'
require_relative 'models/pull_request'
require_relative 'models/review'
require_relative 'models/user'

# Run migrations
ActiveRecord::MigrationContext.new(File.join(File.dirname(__FILE__), 'db/migrate')).migrate

# Test Creating repository record
repo = Repository.create(
  name: 'test-repo',
  url: 'https://github.com/test/repo',
  github_id: 12_345
)

puts "Created repository: #{repo.name}"

# Test creating user record
user = User.create(
  login: 'test-user',
  github_id: 54_321,
  avatar_url: 'https://github.com/avatar.png',
  html_url: 'https://github.com/test-user'
)

puts "Created user: #{user.login}"

# Test creating pull request record
pr = PullRequest.create(
  repository: repo,
  github_id: 67_890,
  number: 1,
  title: 'Test PR',
  pr_updated_at: Time.now,
  author_login: user.login,
  additions: 10,
  deletions: 5,
  changed_files: 2,
  commits_count: 1
)

puts "Created PR ##{pr.number}: #{pr.title}"

# Test creating review record
review = Review.create(
  pull_request: pr,
  github_id: 13_579,
  author_login: user.login,
  state: 'APPROVED',
  submitted_at: Time.now
)

puts "Created review by #{review.author_login} on PR ##{pr.number}"

# Print record counts
puts "\nRecord counts:"
puts "Repository count: #{Repository.count}"
puts "User count: #{User.count}"
puts "Pull Request count: #{PullRequest.count}"
puts "Review count: #{Review.count}"
