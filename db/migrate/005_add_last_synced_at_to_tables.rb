#!/usr/bin/env ruby
# frozen_string_literal: true

# db/migrate/005_add_last_synced_at_to_tables.rb
# Migration to add last_synced_at timestamp to repositories and pull_requests tables
# @author Josh Trujillo
class AddLastSyncedAtToTables < ActiveRecord::Migration[7.0]
  # Adds last_synced_at timestamp column to repositories and pull_requests tables
  # @return [void]
  def up
    add_column :repositories, :last_synced_at, :datetime
    add_column :pull_requests, :last_synced_at, :datetime
  end

  # Removes last_synced_at timestamp column from repositories and pull_requests tables
  # @return [void]
  def down
    remove_column :repositories, :last_synced_at
    remove_column :pull_requests, :last_synced_at
  end
end