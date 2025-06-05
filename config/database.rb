#!/usr/bin/env ruby
# frozen_string_literal: true

# Database configuration file
# Establishes the connection to the SQLite database
# @author Josh Trujillo
# @return [void] Establishes the ActiveRecord database connection

require 'active_record'
require 'dotenv/load'

# Database connection
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'db/github_scraper.db',
  pool: 25  # Increase connection pool size for multithreading
)
