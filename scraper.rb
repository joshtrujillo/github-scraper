#!/usr/bin/env ruby
# frozen_string_literal: true

# scraper.rb
# @author Josh Trujillo

require 'dotenv/load'
require_relative 'config/database'
require_relative 'lib/github_client'
require_relative 'models/repository'
require_relative 'models/pull_request'
require_relative 'models/review'
require_relative 'models/user'

class GitHubScraper
  attr_reader :client, :logger

  ORGANIZATION = 'vercel'

  def initialize
    # Set up GitHub client
    @client = GitHubClient.new
    @logger = @client.logger

    # Run database migrations
    migrate_database

    @logger.info ActiveSupport::LogSubscriber.new.send(:color,
                                                       "GitHub Scraper initialized for organization: #{ORGANIZATION}", :green)
  end

  def run
    @logger.info ActiveSupport::LogSubscriber.new.send(:color, 'Starting GitHub scraper...', :green)

    # Fetch and store repositories
    repositories = fetch_repositories

    # For each repository, fetch and store pull requests
    repositories.each do |repo|
      fetch_pull_requests(repo)
    end

    @logger.info ActiveSupport::LogSubscriber.new.send(:color, 'GitHub scraper completed successfully!', :green)
    log_statistics
  end

  private

  def fetch_repositories
    @logger.info "Fetching repositories for #{ORGANIZATION}..."
    github_repos = @client.fetch_organization_repos(ORGANIZATION)

    @logger.info "Found #{github_repos.size} repositories for #{ORGANIZATION}."

    github_repos.map do |github_repo|
      # Find or create the repository in the database
      repo = Repository.find_or_initialize_by(github_id: github_repo.id)

      # Update repository attributes
      repo.update(
        name: github_repo.name,
        url: github_repo.html_url,
        private: github_repo.private,
        archived: github_repo.archived
      )

      @logger.info "Saved repository: #{repo.name}"
      repo
    end
  end

  def fetch_pull_requests(repo)
    @logger.info "Fetching pull requests for #{repo.name}..."

    # Get the full repository name
    repo_full_name = "#{ORGANIZATION}/#{repo.name}"

    # Fetch all pull requests (both open and closed)
    github_prs = @client.fetch_pull_requests(repo_full_name)

    @logger.info "Found #{github_prs.size} pull requests for #{repo.name}"

    github_prs.each do |github_pr|
      # Get detailed information for this PR
      pr_details = @client.fetch_pull_request_details(repo_full_name, github_pr.number)

      # Find or create the pull request in the database
      pr = PullRequest.find_or_initialize_by(github_id: github_pr.id)

      # Update pull request attributes
      pr.update(
        repository_id: repo.id,
        number: github_pr.number,
        title: github_pr.title,
        pr_updated_at: github_pr.updated_at,
        closed_at: github_pr.closed_at,
        merged_at: github_pr.merged_at,
        author_login: github_pr.user.login,
        additions: pr_details.additions,
        deletions: pr_details.deletions,
        changed_files: pr_details.changed_files,
        commits_count: pr_details.commits
      )

      @logger.info "Saved PR ##{pr.number}: #{pr.title}"

      # Store the PR author in the users table
      store_user(github_pr.user)

      # Fetch and store reviews for this PR
      fetch_reviews(repo_full_name, pr)
    end
  end

  def fetch_reviews(repo_full_name, pr)
    # Fetch all reviews for this PR
    github_reviews = @client.fetch_pull_request_reviews(repo_full_name, pr.number)

    @logger.info "Found #{github_reviews.size} reviews for PR ##{pr.number}."

    github_reviews.each do |github_review|
      # Find or create the review in the database
      review = Review.find_or_initialize_by(github_id: github_review.id)

      # Check if user is nil before accessing login
      if github_review.user.nil?
        @logger.warn "Review #{github_review.id} has no user data. Skipping..."
        next
      end

      # Update review attributes
      review.update(
        pull_request_id: pr.id,
        author_login: github_review.user.login,
        state: github_review.state,
        submitted_at: github_review.submitted_at
      )

      @logger.info "Saved review by #{review.author_login} on PR ##{pr.number}"

      # Store the review author in the users table
      store_user(github_review.user)
    end
  end

  def store_user(github_user)
    return if github_user.nil?

    # Find or create the user in the database
    user = User.find_or_initialize_by(github_id: github_user.id)

    # Update user attributes
    user.update(
      login: github_user.login,
      avatar_url: github_user.avatar_url,
      html_url: github_user.type
    )

    @logger.debug "Saved user: #{user.login}" if user.saved_changes?
  end

  def migrate_database
    @logger.info 'Running database migrations...'
    ActiveRecord::MigrationContext.new(File.join(File.dirname(__FILE__), 'db/migrate')).migrate
    @logger.info 'Database migrations completed.'
  end

  def log_statistics
    repos_count = Repository.count
    prs_count = PullRequest.count
    reviews_count = Review.count
    users_count = User.count

    @logger.info '--- GitHub Scraper Statistics ---'
    @logger.info "Repositories: #{repos_count}"
    @logger.info "Pull Requests: #{prs_count}"
    @logger.info "Reviews: #{reviews_count}"
    @logger.info "Users: #{users_count}"
    @logger.info '---------------------------------'
  end
end

if __FILE__ == $PROGRAM_NAME
  scraper = GitHubScraper.new
  scraper.run
end
