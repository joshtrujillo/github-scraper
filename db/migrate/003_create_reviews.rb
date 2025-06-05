#!/usr/bin/env ruby
# frozen_string_literal: true

# db/migrate/003_create_reviews.rb
# @author Josh Trujillo

class CreateReviews < ActiveRecord::Migration[7.0]
  def change
    create_table :reviews do |t|
      t.references :pull_request, null: false, foreign_key: true
      t.integer :github_id, null: false
      t.string :author_login, null: false
      t.string :state, null: false
      t.datetime :submitted_at, null: false
      t.timestamps
    end

    add_index :reviews, :github_id, unique: true
  end
end
