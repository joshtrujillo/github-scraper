#!/usr/bin/env ruby
# frozen_string_literal: true

# scraper.rb
# @author Josh Trujillo
# Main entry point to GitHub scraper.
# Uses ActiveRecord to model the sqlite database scheme.

require 'dotenv/load'
require 'parallel'
require_relative 'config/database'
require_relative 'lib/github_client'
require_relative 'models/repository'
require_relative 'models/pull_request'
require_relative 'models/review'
require_relative 'models/user'

# GitHubScraper class is used to control the logic for
# the scraping by calling methods provided by the GitHubClient class.
class GitHubScraper
  attr_reader :client, :logger

  ORGANIZATION = 'vercel'
  THREADS = 5 # Number of threads to use

  # Creates GitHub client and logger instance variables.
  # Runs Database migrations
  # @return [void]
  def initialize(verbose: false, thread: false)
    @thread = thread
    @verbose = verbose

    # Set up GitHub client and pass thread flag to control mutex usage
    @client = GitHubClient.new(nil, 3600, thread: @thread)
    @logger = @client.logger

    # Set debug flag on client for thread-specific logging
    @client.debug = @verbose

    # Set logger to DEBUG level if verbose
    @logger.level = Logger::DEBUG if @verbose

    # Run database migrations
    migrate_database
    @logger.info ActiveSupport::LogSubscriber.new.send(
      :color,
      "GitHub Scraper initialized for organization: #{ORGANIZATION}",
      :green
    )
  end

  # Main method to execute client method calls. The client ends up making
  # the API requests.
  # @param incremental [Boolean] Whether to perform an incremental sync (default: true)
  # @return [void]
  def run(incremental: true)
    @logger.info ActiveSupport::LogSubscriber.new.send(
      :color,
      "Starting GitHub scraper (#{incremental ? 'incremental' : 'full'} sync)...",
      :green
    )
    # Fetch and store repositories
    repositories = fetch_repositories(incremental: incremental)
    # For each repository, fetch and store pull requests in parallel
    if @thread
      Parallel.each(repositories, in_threads: THREADS) do |repo|
        fetch_pull_requests(repo)
      end
    else
      repositories.each do |repo|
        fetch_pull_requests(repo)
      end
    end
    @logger.info ActiveSupport::LogSubscriber.new.send(
      :color,
      'GitHub scraper completed successfully!',
      :green
    )
    log_statistics
  end

  private

  # Uses Repository objects to find or insert each
  # repo into the database. Updates the database row if needed.
  # If incremental is true, only fetches repos updated since last sync.
  #
  # @param incremental [Boolean] Whether to perform an incremental sync
  # @return [Array<Repository>] list of repositories
  def fetch_repositories(incremental: true)
    @logger.info "Fetching repositories for #{ORGANIZATION}..."

    # Get the oldest last_synced_at time from repositories
    last_sync_time = incremental ? Repository.minimum(:last_synced_at) : nil

    @logger.info "Using incremental sync (last synced: #{last_sync_time})" if incremental && last_sync_time

    # Fetch repositories, filtered by update time if available
    github_repos = @client.fetch_organization_repos(ORGANIZATION, last_sync_time)
    @logger.info "Found #{github_repos.size} repositories for #{ORGANIZATION}."

    github_repos.map do |github_repo|
      # Find or create the repository in the database
      repo = Repository.find_or_initialize_by(github_id: github_repo.id)

      # Skip update if repo hasn't changed since last sync
      if !repo.new_record? && repo.last_synced_at && github_repo.updated_at <= repo.last_synced_at
        @logger.info "Skipping unchanged repository: #{repo.name}"
        next repo
      end

      # Update repository attributes
      repo.update(
        name: github_repo.name,
        url: github_repo.html_url,
        private: github_repo.private,
        archived: github_repo.archived,
        last_synced_at: Time.now
      )
      @logger.info "Saved repository: #{repo.name}"
      repo
    end.compact
  end

  # Fetches the pull requests for the given
  # repo with the client. Finds, inserts, updates in the database.
  # Each PR has its reviews and users fetched and stored as well.
  # If repo has been synced before, only fetch PRs updated since last sync.
  #
  # @param repo [Repository] repository whose PRs to fetch
  # @return [void]
  def fetch_pull_requests(repo)
    @logger.info "Fetching pull requests for #{repo.name}..."
    # Get the full repository name
    repo_full_name = "#{ORGANIZATION}/#{repo.name}"
    # Only fetch PRs updated since last sync if we've synced before
    since_time = repo.last_synced_at
    @logger.info "Using incremental sync for #{repo.name} (last synced: #{since_time})" if since_time
    # Fetch pull requests (both open and closed), filtered by updated time if available
    github_prs = @client.fetch_pull_requests(repo_full_name, 'all', since_time)
    @logger.info "Found #{github_prs.size} pull requests for #{repo.name}"

    if @thread
      # Process PRs in parallel
      Parallel.each(github_prs, in_threads: THREADS) do |github_pr|
        # Get detailed information for this PR
        pr_details = @client.fetch_pull_request_details(repo_full_name, github_pr.number)

        # Critical Section
        ActiveRecord::Base.connection_pool.with_connection do
          process_pr(github_pr, pr_details, repo_full_name, repo)
        end
      end
    else
      # Process PRs sequentially
      github_prs.each do |github_pr|
        # Get detailed information for this PR
        pr_details = @client.fetch_pull_request_details(repo_full_name, github_pr.number)
        process_pr(github_pr, pr_details, repo_full_name, repo)
      end
    end

    # Update repository sync timestamp
    repo.update(last_synced_at: Time.now)
  end

  def process_pr(github_pr, pr_details, repo_full_name, repo)
    # Find or create the pull request in the database
    pr = PullRequest.find_or_initialize_by(github_id: github_pr.id)

    # Skip if PR hasn't changed since last sync (compare database updated_at with GitHub updated_at)
    if !pr.new_record? && pr.last_synced_at && pr.pr_updated_at >= github_pr.updated_at
      @logger.info "Skipping unchanged PR ##{pr.number}: #{pr.title}"
      return
    end

    # Skip if PR details couldn't be fetched
    if pr_details.nil?
      @logger.warn "Could not fetch details for PR ##{github_pr.number} in #{repo_full_name}. Skipping."
      return
    end

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
      commits_count: pr_details.commits,
      last_synced_at: Time.now
    )
    @logger.info "Saved PR ##{pr.number}: #{pr.title}"
    # Store the PR author in the users table
    store_user(github_pr.user)
    # Fetch and store reviews for this PR
    fetch_reviews(repo_full_name, pr)
  end

  # Fetches all reviews for a PR
  # Calls store_user
  #
  # @param repo_full_name [String] Full GitHub repository name
  # @param pr [PullRequest] The PR whose reviews to fetch
  # @return [void]
  def fetch_reviews(repo_full_name, pr)
    # API request - fetch all reviews for this PR
    github_reviews = @client.fetch_pull_request_reviews(repo_full_name, pr.number)
    @logger.info "Found #{github_reviews.size} reviews for PR ##{pr.number}."

    # Use parallel processing if:
    # 1. Threads are enabled globally via @thread flag AND
    # 2. Either we have enough reviews to make it worthwhile OR verbose logging is enabled
    if @thread && (github_reviews.size > 3 || @verbose)
      @logger.debug "Processing #{github_reviews.size} reviews in parallel for PR ##{pr.number}"

      # Process reviews in parallel - this creates a thread pool and distributes work
      # [THREADS, github_reviews.size].min ensures we don't create more threads than needed
      Parallel.each(github_reviews, in_threads: [THREADS, github_reviews.size].min) do |github_review|
        # Each review is processed in its own thread
        process_review(github_review, pr)
      end
    else
      # For small numbers of reviews or when threading is disabled, process sequentially
      github_reviews.each do |github_review|
        process_review(github_review, pr)
      end
    end
  end

  # Extracted method to process a single review
  # This allows the same code to be used by both parallel and sequential workflows
  # @param github_review [Sawyer::Resource] The GitHub review to process
  # @param pr [PullRequest] The PR this review belongs to
  # @return [void]
  def process_review(github_review, pr)
    # Critical section
    ActiveRecord::Base.connection_pool.with_connection do
      # Find or create the review in the database
      review = Review.find_or_initialize_by(github_id: github_review.id)

      # Check if user is nil before accessing login
      if github_review.user.nil?
        @logger.warn "Review #{github_review.id} has no user data. Skipping..."
        return
      end

      # Update review attributes
      review.update(
        pull_request_id: pr.id,
        author_login: github_review.user.login,
        state: github_review.state,
        submitted_at: github_review.submitted_at
      )
      # Log with thread info in verbose mode for better visibility of parallel operations
      thread_id = Thread.current.object_id.to_s(16)
      if @verbose
        @logger.debug "Thread-#{thread_id} saved review by #{review.author_login} on PR ##{pr.number}"
      else
        @logger.info "Saved review by #{review.author_login} on PR ##{pr.number}"
      end

      # Store the review author in the users table
      store_user(github_review.user)
    end
  end

  # Finds or inserts the user into the database.
  # Returns early if given user is nil.
  #
  # @param github_user [Sawyer::Resource] A GitHub user object
  # @return [User, nil] The saved user or nil if github_user was nil
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

  # Runs database migrations.
  # Creates tables for repositories, pull requests, reviews, and users.
  # @return [void]
  def migrate_database
    @logger.info 'Running database migrations...'
    ActiveRecord::MigrationContext.new(File.join(File.dirname(__FILE__), 'db/migrate')).migrate
    @logger.info 'Database migrations completed.'
  end

  # Prints simple statistics when scraping is complete.
  # @return [void]
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
  require 'optparse'

  options = { incremental: true, verbose: false, thread: false }

  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: ruby scraper.rb [options]'

    opts.on(
      '-f',
      '--full',
      'Perform a full sync instead of incremental'
    ) do
      options[:incremental] = false
    end

    opts.on(
      '-v',
      '--verbose',
      'Enable verbose logging with thread information'
    ) do
      options[:verbose] = true
    end

    opts.on(
      '-t',
      '--thread',
      'Enables multithreading'
    ) do
      options[:thread] = true
    end

    opts.on('-h', '--help', 'Display this help message') do
      puts opts
      exit
    end
  end

  parser.parse!

  scraper = GitHubScraper.new(
    verbose: options[:verbose],
    thread: options[:thread]
  )
  scraper.run(incremental: options[:incremental])
end
