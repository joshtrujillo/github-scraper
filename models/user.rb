#!/usr/bin/env ruby
# frozen_string_literal: true

# model/user
# User model representing a GitHub user
# @author Josh Trujillo
class User < ActiveRecord::Base
  # Validations
  validates :login, presence: true, uniqueness: true
  validates :github_id, presence: true, uniqueness: true
end
