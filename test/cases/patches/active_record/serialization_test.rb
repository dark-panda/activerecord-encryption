# frozen_string_literal: true

require "cases/helper"

class SerializedAttributeTest < ActiveRecord::TestCase
  fixtures :topics

  MyObject = Struct.new :attribute1, :attribute2

  class Topic < ActiveRecord::Base
    serialize :content
  end

  class ImportantTopic < Topic
    serialize :important, Hash
  end

  teardown do
    Topic.serialize("content")
  end

  class EncryptedType < ActiveRecord::Type::Text
    include ActiveModel::Type::Helpers::Mutable

    attr_reader :subtype, :encryptor

    def initialize(subtype: ActiveModel::Type::String.new)
      super()

      @subtype   = subtype
      @encryptor = ActiveSupport::MessageEncryptor.new("abcd" * 8)
    end

    def serialize(value)
      subtype.serialize(value).yield_self do |cleartext|
        encryptor.encrypt_and_sign(cleartext) unless cleartext.nil?
      end
    end

    def deserialize(ciphertext)
      encryptor.decrypt_and_verify(ciphertext)
        .yield_self { |cleartext| subtype.deserialize(cleartext) } unless ciphertext.nil?
    end

    def changed_in_place?(old, new)
      if old.nil?
        !new.nil?
      else
        deserialize(old) != new
      end
    end
  end

  def test_decorated_type_with_type_for_attribute
    old_registry = ActiveRecord::Type.registry
    ActiveRecord::Type.registry = ActiveRecord::Type.registry.dup
    ActiveRecord::Type.register :encrypted, EncryptedType

    klass = Class.new(ActiveRecord::Base) do
      self.table_name = Topic.table_name
      store :content
      attribute :content, :encrypted, subtype: type_for_attribute(:content)
    end

    topic = klass.create!(content: { trial: true })

    assert_equal({ "trial" => true }, topic.content)
  ensure
    ActiveRecord::Type.registry = old_registry
  end

  def test_decorated_type_with_decorator_block
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = Topic.table_name
      store :content
      attribute(:content) { |subtype| EncryptedType.new(subtype: subtype) }
    end

    topic = klass.create!(content: { trial: true })

    assert_equal({ "trial" => true }, topic.content)
  end

  def test_mutation_detection_does_not_double_serialize
    coder = Object.new
    def coder.dump(value)
      return if value.nil?
      value + " encoded"
    end
    def coder.load(value)
      return if value.nil?
      value.gsub(" encoded", "")
    end
    type = Class.new(ActiveModel::Type::Value) do
      include ActiveModel::Type::Helpers::Mutable

      def serialize(value)
        return if value.nil?
        value + " serialized"
      end

      def deserialize(value)
        return if value.nil?
        value.gsub(" serialized", "")
      end
    end.new
    model = Class.new(Topic) do
      attribute :foo, type
      serialize :foo, coder
    end

    topic = model.create!(foo: "bar")
    topic.foo
    assert_not_predicate topic, :changed?
  end

  def test_serialized_attribute_works_under_concurrent_initial_access
    model = Class.new(Topic)

    topic = model.create!
    topic.update group: "1"

    model.serialize :group, JSON
    model.reset_column_information

    # This isn't strictly necessary for the test, but a little bit of
    # knowledge of internals allows us to make failures far more likely.
    model.define_singleton_method(:define_attribute) do |*args, **options|
      Thread.pass
      super(*args, **options)
    end

    threads = 4.times.map do
      Thread.new do
        topic.reload.group
      end
    end

    # All the threads should retrieve the value knowing it is JSON, and
    # thus decode it. If this fails, some threads will instead see the
    # raw string ("1"), or raise an exception.
    assert_equal [1] * threads.size, threads.map(&:value)
  end
end

class OverloadedType < ActiveRecord::Base
  attribute :overloaded_float, :integer
  attribute :overloaded_string_with_limit, :string, limit: 50
  attribute :non_existent_decimal, :decimal
  attribute :string_with_default, :string, default: "the overloaded default"
end

class ChildOfOverloadedType < OverloadedType
end

class GrandchildOfOverloadedType < ChildOfOverloadedType
  attribute :overloaded_float, :float
end

class UnoverloadedType < ActiveRecord::Base
  self.table_name = "overloaded_types"
end

module ActiveRecord
  class CustomPropertiesTest < ActiveRecord::TestCase
    test "attributes with overridden types keep their type when a default value is configured separately" do
      child = Class.new(OverloadedType) do
        attribute :overloaded_float, default: "123"
      end

      assert_equal OverloadedType.type_for_attribute("overloaded_float"), child.type_for_attribute("overloaded_float")
      assert_equal 123, child.new.overloaded_float
    end

    test "attributes not backed by database columns keep their type when a default value is configured separately" do
      child = Class.new(OverloadedType) do
        attribute :non_existent_decimal, default: "123"
      end

      assert_equal OverloadedType.type_for_attribute("non_existent_decimal"), child.type_for_attribute("non_existent_decimal")
      assert_equal 123, child.new.non_existent_decimal
    end

    private
      def with_immutable_strings
        old_value = ActiveRecord::Base.immutable_strings_by_default
        ActiveRecord::Base.immutable_strings_by_default = true
        yield
      ensure
        ActiveRecord::Base.immutable_strings_by_default = old_value
      end
  end
end
