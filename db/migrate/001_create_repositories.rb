#!/usr/bin/env ruby
# frozen_string_literal: true

# db/migrate/001_create_repositories.rb
# Migration to create the repositories table
# @author Josh Trujillo
class CreateRepositories < ActiveRecord::Migration[7.0]
  # Creates the repositories table and indexes
  # @return [void]
  def change
    create_table :repositories do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.boolean :private, default: false
      t.boolean :archived, default: false
      t.integer :github_id, null: false
      t.timestamps
    end

    add_index :repositories, :github_id, unique: true
  end
end
