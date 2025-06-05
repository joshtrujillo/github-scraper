#!/usr/bin/env ruby
# frozen_string_literal: true

# models/repository.rb
# Repository model representing a GitHub repository
# @author Josh Trujillo
class Repository < ActiveRecord::Base
  # Data integrity
  validates :name, presence: true
  validates :github_id, presence: true, uniqueness: true

  # Relationships
  # One repository to many pull requests
  # @return [ActiveRecord::Associations::CollectionProxy<PullRequest>] Collection of associated pull requests
  has_many :pull_requests, dependent: :destroy # Cascade deletion
end
