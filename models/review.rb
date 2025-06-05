#!/usr/bin/env ruby
# frozen_string_literal: true

# models/review.rb
# @author Josh Trujillo

class Review < ActiveRecord::Base
  # Relationships
  belongs_to :pull_request

  # Validations
  validates :github_id, presence: true, uniqueness: true
  validates :author_login, presence: true
  validates :state, presence: true
  validates :submitted_at, presence: true
end
