# frozen_string_literal: true

namespace :db do
  namespace :encryption do
    desc "Generate a set of keys for configuring Active Record encryption in a given environment"
    task :init do
      puts <<~MSG
        Add this entry to the credentials of the target environment:#{' '}

        active_record_encryption:
          primary_key: #{SecureRandom.alphanumeric(32)}
          deterministic_key: #{SecureRandom.alphanumeric(32)}
          key_derivation_salt: #{SecureRandom.alphanumeric(32)}
      MSG
    end
  end
end
