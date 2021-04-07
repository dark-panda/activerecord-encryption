# frozen_string_literal: true

require File.expand_path("../lib/active_record/encryption/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "activerecord-encryption"
  s.version = ActiveRecord::Encryption::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["J Smith", "Jorge Manrubia"]
  s.description = "ActiveRecord::Encryption is an extraction of the Rails 7 AR encryption infrastructure for use in Rails 6."
  s.summary = s.description
  s.email = "dark.panda@gmail.com"
  s.license = "MIT"
  s.extra_rdoc_files = [
    "README.md"
  ]
  s.files = `git ls-files`.split($OUTPUT_RECORD_SEPARATOR)
  s.executables = s.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  s.test_files = s.files.grep(%r{^(test|spec|features)/})
  s.homepage = "https://github.com/dark-panda/activerecord-encryption"
  s.require_paths = ["lib"]

  s.add_dependency("rails", ["~> 6"])
end
