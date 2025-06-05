#!/usr/bin/env ruby
# frozen_string_literal: true

# config/database.rb
# @author Josh Trujillo

require 'active_record'
require 'dotenv/load'

# Database connection
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'db/github_scraper.db'
)
