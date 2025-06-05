#!/usr/bin/env ruby
# frozen_string_literal: true

# db/migrate/004_create_users.rb
# Migration to create the users table
# @author Josh Trujillo
class CreateUsers < ActiveRecord::Migration[7.0]
  # Creates the users table and indexes
  # @return [void]
  def change
    create_table :users do |t|
      t.string :login, null: false
      t.integer :github_id, null: false
      t.string :avatar_url
      t.string :html_url
      t.string :user_type
      t.timestamps
    end

    add_index :users, :login, unique: true
    add_index :users, :github_id, unique: true
  end
end
