#!/usr/bin/env ruby
# frozen_string_literal: true

# models/pull_request.rb
# @author Josh Trujillo

class PullRequest < ActiveRecord::Base
  # Relationships
  # One PR to many reviews
  has_many :reviews, dependent: :destroy # Cascade
  belongs_to :repository

  # Validations
  validates :github_id, presence: true, uniqueness: true
  validates :number, presence: true, uniqueness: { scope: :repository_id }
  validates :title, presence: true
  validates :author_login, presence: true
end
