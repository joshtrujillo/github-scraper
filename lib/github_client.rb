#!/usr/bin/env ruby
# frozen_string_literal: true

# lib/github_client.rb
require 'octokit'
require 'logger'

# GitHub API client wrapper
# @author Josh Trujillo
class GitHubClient
  # @return [Octokit::Client] The underlying Octokit client
  # @return [Logger] Logger instance for this client
  attr_reader :client, :logger

  # Initialize a new GitHub client
  # @param access_token [String, nil] GitHub API token (uses ENV if nil)
  # @return [void]
  def initialize(access_token = nil)
    @access_token = access_token || ENV['GITHUB_ACCESS_TOKEN']
    @logger = Logger.new($stdout)
    @logger.level = Logger::INFO

    if @access_token.nil? || @access_token.empty?
      @logger.warn 'No GitHub access token provided. Using unauthenticated client with severe rate limits.'
      @client = Octokit::Client.new
    else
      @client = Octokit::Client.new(access_token: @access_token)
      @logger.info "Authenticated as #{@client.user.login}"
    end

    # Auto-paginate results
    @client.auto_paginate = true
  end

  # Fetch all public repositories for an organization
  # @param org_name [String] Organization name
  # @return [Array<Sawyer::Resource>] List of repository resources
  def fetch_organization_repos(org_name)
    with_error_handling do
      @logger.info "Fetching repositories for #{org_name}..."
      @client.organization_repositories(org_name, type: 'public')
    end
  end

  # Fetch all pull requests for a repository (default: all pull requests, both open and closed)
  # @param repo_full_name [String] Full repository name in format 'owner/repo'
  # @param state [String] Pull request state ('open', 'closed', or 'all')
  # @return [Array<Sawyer::Resource>] List of pull request resources
  def fetch_pull_requests(repo_full_name, state = 'all')
    with_error_handling do
      @logger.info "Fetching #{state} pull requests for #{repo_full_name}..."
      @client.pull_requests(repo_full_name, state: state)
    end
  end

  # Fetch a specific pull request with detailed information
  # @param repo_full_name [String] Full repository name in format 'owner/repo'
  # @param pull_number [Integer] Pull request number
  # @return [Sawyer::Resource] Pull request details
  def fetch_pull_request_details(repo_full_name, pull_number)
    with_error_handling do
      @logger.info "Fetching details for PR ##{pull_number} in #{repo_full_name}..."
      @client.pull_request(repo_full_name, pull_number)
    end
  end

  # Fetch reviews for a specific pull request
  # @param repo_full_name [String] Full repository name in format 'owner/repo'
  # @param pull_number [Integer] Pull request number
  # @return [Array<Sawyer::Resource>] List of review resources
  def fetch_pull_request_reviews(repo_full_name, pull_number)
    with_error_handling do
      @logger.info "Fetching reviews for PR ##{pull_number} in #{repo_full_name}..."
      @client.pull_request_reviews(repo_full_name, pull_number)
    end
  end

  # Fetch a specific user
  # @param username [String] GitHub username
  # @return [Sawyer::Resource, nil] User details or nil if not found
  def fetch_user(username)
    with_error_handling do
      @logger.info "Fetching user data for #{username}..."
      @client.user(username)
    end
  end

  # Get current rate limit status
  # @return [Sawyer::Resource] Rate limit information
  def rate_limit_status
    @client.rate_limit
  end

  private

  # Wrapper method for API calls with standardized error handling
  # @yield The API call to execute
  # @return [Object, nil] The result of the API call or nil if error
  def with_error_handling
    retries = 0
    max_retries = 3
    delay = 2

    begin
      # Check rate limit before making request
      check_rate_limit

      # Make the API call
      yield
    rescue Octokit::TooManyRequests => e
      # Handle rate limit exceeded
      handle_rate_limit_exceeded
      retry
    rescue Octokit::NotFound => e
      # Resource not found
      @logger.warn ActiveSupport::LogSubscriber.new.send(:color, "Resource not found: #{e.message}", :yellow)
      nil
    rescue Octokit::Unauthorized, Octokit::Forbidden => e
      # Auth or permission issues
      @logger.error ActiveSupport::LogSubscriber.new.send(:color, "Authorization error: #{e.message}", :red)
      raise e
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Octokit::ServerError => e
      # Network or server error - use exponential timeout
      if retries < max_retries
        retries += 1
        wait_time = delay**retries
        @logger.warn ActiveSupport::LogSubscriber.new.send(:color,
                                                           "Network/server error: #{e.message}. Retrying in #{wait_time} seconds (#{retries}/#{max_retries})", :yellow)
        sleep(wait_time)
        retry
      else
        @logger.error ActiveSupport::LogSubscriber.new.send(:color,
                                                            "Network/server error: #{e.message}. Max retries reached.", :red)
        raise e
      end
    rescue StandardError => e
      # Anything else
      @logger.error "Unexpected error: #{e.message}\n#{e.backtrace.join("\n")}"
      raise e
    end
  end

  # Rate limit handling - checks and waits if limits are near
  # @return [void]
  def check_rate_limit
    # Check if near the rate limit before making a request
    rate_limit = @client.rate_limit
    remaining = rate_limit.remaining

    if remaining <= 0
      reset_time = Time.at(rate_limit.resets_at)
      wait_time = reset_time - Time.now

      if wait_time.positive?
        @logger.warn "Rate limit depleted! Waiting for #{wait_time.ceil} seconds until reset at #{reset_time}..."
        @logger.warn ActiveSupport::LogSubscriber.new.send(:color,
                                                           "Rate limit depleted! Waiting for #{wait_time.ceil} seconds until reset at #{reset_time}...", :yellow)
        sleep(wait_time.ceil)
      end
    # If less than 10% of limit remaining, slow down
    elsif remaining < (rate_limit.limit * 0.1) && remaining.positive?
      @logger.warn ActiveSupport::LogSubscriber.new.send(:color,
                                                         "Running low on rate limit: #{remaining} requests remaining.", :yellow)
      sleep(1) # Delay between requests
    end
  end

  # Handles case when rate limit is exceeded
  # @return [void]
  def handle_rate_limit_exceeded
    rate_limit = @client.rate_limit
    reset_time = Time.at(rate_limit.resets_at)
    wait_time = reset_time - Time.now
    return unless wait_time.positive?

    @logger.warn ActiveSupport::LogSubscriber.new.send(:color,
                                                       "Rate limit exceeded! Waiting for #{wait_time.ceil} seconds until reset at #{reset_time}...", :yellow)
    sleep(wait_time.ceil)
  end
end
