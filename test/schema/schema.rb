# frozen_string_literal: true

ActiveRecord::Schema.define do
  # ------------------------------------------------------------------- #
  #                                                                     #
  #   Please keep these create table statements in alphabetical order   #
  #   unless the ordering matters.  In which case, define them below.   #
  #                                                                     #
  # ------------------------------------------------------------------- #

  create_table :articles, force: true do |t|
  end

  create_table :authors, force: true do |t|
    t.string :name, null: false
    t.references :author_address
    t.references :author_address_extra
    t.string :organization_id
    t.string :owned_essay_id
  end

  create_table :books, id: :integer, force: true do |t|
    default_zero = { default: 0 }
    t.references :author
    t.string :format
    t.column :name, :string
    t.column :status, :integer, **default_zero
    t.column :last_read, :integer, **default_zero
    t.column :nullable_status, :integer
    t.column :language, :integer, **default_zero
    t.column :author_visibility, :integer, **default_zero
    t.column :illustrator_visibility, :integer, **default_zero
    t.column :font_size, :integer, **default_zero
    t.column :difficulty, :integer, **default_zero
    t.column :cover, :string, default: "hard"
    t.string :isbn
    t.string :external_id
    t.column :original_name, :string
    t.datetime :published_on
    t.boolean :boolean_status
    t.index [:author_id, :name], unique: true
    t.integer :tags_count, default: 0
    t.index :isbn, where: "published_on IS NOT NULL", unique: true
    t.index "(lower(external_id))", unique: true if supports_expression_index?

    t.datetime :created_at
    t.datetime :updated_at
    t.date :updated_on
  end

  create_table :encrypted_books, id: :integer, force: true do |t|
    t.references :author
    t.string :format
    t.column :name, :string
    t.column :original_name, :string

    t.datetime :created_at
    t.datetime :updated_at
  end

  disable_referential_integrity do
    create_table :pirates, force: :cascade do |t|
      t.string :catchphrase
      t.integer :parrot_id
      t.integer :non_validated_parrot_id
      if supports_datetime_with_precision?
        t.datetime :created_on, precision: 6
        t.datetime :updated_on, precision: 6
      else
        t.datetime :created_on
        t.datetime :updated_on
      end
    end
  end

  create_table :posts, force: true do |t|
    t.references :author
    t.string :title, null: false
    # use VARCHAR2(4000) instead of CLOB datatype as CLOB data type has many limitations in
    # Oracle SELECT WHERE clause which causes many unit test failures
    if current_adapter?(:OracleAdapter)
      t.string  :body, null: false, limit: 4000
    else
      t.text    :body, null: false
    end
    t.string  :type
    t.integer :legacy_comments_count, default: 0
    t.integer :taggings_with_delete_all_count, default: 0
    t.integer :taggings_with_destroy_count, default: 0
    t.integer :tags_count, default: 0
    t.integer :indestructible_tags_count, default: 0
    t.integer :tags_with_destroy_count, default: 0
    t.integer :tags_with_nullify_count, default: 0
  end

  create_table :traffic_lights, force: true do |t|
    t.string   :location
    t.string   :state
    t.text     :long_state, null: false
    t.datetime :created_at
    t.datetime :updated_at
  end

  create_table :topics, force: true do |t|
    t.string   :title, limit: 250
    t.string   :author_name
    t.string   :author_email_address
    if supports_datetime_with_precision?
      t.datetime :written_on, precision: 6
    else
      t.datetime :written_on
    end
    t.time     :bonus_time
    t.date     :last_read
    # use VARCHAR2(4000) instead of CLOB datatype as CLOB data type has many limitations in
    # Oracle SELECT WHERE clause which causes many unit test failures
    if current_adapter?(:OracleAdapter)
      t.string   :content, limit: 4000
      t.string   :important, limit: 4000
    else
      t.text     :content
      t.text     :important
    end
    t.boolean  :approved, default: true
    t.integer  :replies_count, default: 0
    t.integer  :unique_replies_count, default: 0
    t.integer  :parent_id
    t.string   :parent_title
    t.string   :type
    t.string   :group
    t.timestamps null: true
    t.index [:author_name, :title]
  end

  create_table :overloaded_types, force: true do |t|
    t.float :overloaded_float, default: 500
    t.float :unoverloaded_float
    t.string :overloaded_string_with_limit, limit: 255
    t.string :string_with_default, default: "the original default"
    t.string :inferred_string, limit: 255
    t.datetime :starts_at, :ends_at
  end
end
