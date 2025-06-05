#!/usr/bin/env ruby
# frozen_string_literal: true

# db/migrate/002_create_pull_request.rb
# Migration to create the pull_requests table
# @author Josh Trujillo
class CreatePullRequests < ActiveRecord::Migration[7.0]
  # Creates the pull_requests table and indexes
  # @return [void]
  def change
    create_table :pull_requests do |t|
      t.references :repository, null: false, foreign_key: true
      t.integer :github_id, null: false
      t.integer :number, null: false
      t.string :title, null: false
      t.datetime :pr_updated_at, null: false
      t.datetime :closed_at
      t.datetime :merged_at
      t.string :author_login, null: false
      t.integer :additions
      t.integer :deletions
      t.integer :changed_files
      t.integer :commits_count
      t.timestamps
    end

    add_index :pull_requests, %i[repository_id number], unique: true
    add_index :pull_requests, :github_id, unique: true
  end
end
