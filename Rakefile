# frozen_string_literal: true

require "rake/testtask"

$LOAD_PATH.push File.expand_path(File.dirname(__FILE__), "lib")

desc "Test ActiveRecord::Encryption #{ActiveRecord::Encryption::VERSION}"
Rake::TestTask.new(:test) do |t|
  dash_i = [
    "test",
    "lib"
  ].map { |dir| File.expand_path(dir, __dir__) }

  dash_i.reverse_each do |x|
    $LOAD_PATH.unshift(x) unless $LOAD_PATH.include?(x)
    t.libs << x
  end

  t.test_files = FileList["test/cases/**/*_test.rb"].reject { |x|
    x.include?("/encryption/performance")
  }

  t.verbose = !!ENV["VERBOSE_TESTS"]
  t.warning = !!ENV["WARNINGS"]
end

task default: :test
