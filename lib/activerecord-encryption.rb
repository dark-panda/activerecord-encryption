# frozen_string_literal: true

require "patches/active_record/serialization"
require "active_record/encryption"

module ActiveRecord::Encryption
  class Railtie < Rails::Railtie
    initializer "active_record_encryption.configuration" do |app|
      ActiveRecord::Encryption.configure \
        primary_key: app.credentials.dig(:active_record_encryption, :primary_key),
        deterministic_key: app.credentials.dig(:active_record_encryption, :deterministic_key),
        key_derivation_salt: app.credentials.dig(:active_record_encryption, :key_derivation_salt),
        **(config.active_record.encryption || {})

      ActiveSupport.on_load(:active_record) do
        # Support extended queries for deterministic attributes and validations
        if ActiveRecord::Encryption.config.extend_queries
          ActiveRecord::Encryption::ExtendedDeterministicQueries.install_support
          ActiveRecord::Encryption::ExtendedDeterministicUniquenessValidator.install_support
        end
      end

      ActiveSupport.on_load(:active_record_fixture_set) do
        # Encrypt active record fixtures
        if ActiveRecord::Encryption.config.encrypt_fixtures
          ActiveRecord::Fixture.prepend ActiveRecord::Encryption::EncryptedFixtures
        end
      end

      # Filtered params
      ActiveSupport.on_load(:action_controller) do
        if ActiveRecord::Encryption.config.add_to_filter_parameters
          ActiveRecord::Encryption.install_auto_filtered_parameters(app)
        end
      end
    end

    rake_tasks do
      load "tasks/encryption.rake"
    end
  end
end

ActiveRecord::Base.include ActiveRecord::Encryption::EncryptableRecord
