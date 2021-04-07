# frozen_string_literal: true

require "active_record/attribute_methods/serialization"
require "active_record/attributes"

# Backport of fix for https://github.com/rails/rails/issues/41138
ActiveRecord::AttributeMethods::Serialization::ClassMethods.class_eval do
  Coders = ActiveRecord::Coders
  Type = ActiveRecord::Type

  def serialize(attr_name, class_name_or_coder = Object, **options)
    # When ::JSON is used, force it to go through the Active Support JSON encoder
    # to ensure special objects (e.g. Active Record models) are dumped correctly
    # using the #as_json hook.
    coder = if class_name_or_coder == ::JSON
      Coders::JSON
    elsif [:load, :dump].all? { |x| class_name_or_coder.respond_to?(x) }
      class_name_or_coder
    else
      Coders::YAMLColumn.new(attr_name, class_name_or_coder)
    end

    attribute(attr_name, **options) do |cast_type|
      if type_incompatible_with_serialize?(cast_type, class_name_or_coder)
        raise ColumnNotSerializableError.new(attr_name, cast_type)
      end

      cast_type = cast_type.subtype if Type::Serialized === cast_type
      Type::Serialized.new(cast_type, coder)
    end
  end
end

ActiveRecord::Attributes::ClassMethods.class_eval do
  NO_DEFAULT_PROVIDED = ActiveRecord::Attributes::ClassMethods.const_get(:NO_DEFAULT_PROVIDED)

  def attribute(name, cast_type = nil, default: NO_DEFAULT_PROVIDED, **options, &block)
    name = name.to_s
    reload_schema_from_cache

    case cast_type
    when Symbol
      type = cast_type
      cast_type = -> _ { ActiveRecord::Type.lookup(type, **options, adapter: ActiveRecord::Type.adapter_name_from(self)) }
    when nil
      if (prev_cast_type, prev_default = attributes_to_define_after_schema_loads[name])
        default = prev_default if default == NO_DEFAULT_PROVIDED

        cast_type = if block_given?
          -> subtype { yield Proc === prev_cast_type ? prev_cast_type[subtype] : prev_cast_type }
        else
          prev_cast_type
        end
      else
        cast_type = block || -> subtype { subtype }
      end
    end

    self.attributes_to_define_after_schema_loads =
      attributes_to_define_after_schema_loads.merge(name => [cast_type, default])
  end

  def load_schema! # :nodoc:
    super
    attributes_to_define_after_schema_loads.each do |name, (cast_type, default)|
      cast_type = cast_type[type_for_attribute(name)] if Proc === cast_type
      define_attribute(name, cast_type, default: default)
    end
  end
end

ActiveRecord::Enum.class_eval do
  EnumType = ActiveRecord::Enum::EnumType

  def enum(definitions)
    enum_prefix = definitions.delete(:_prefix)
    enum_suffix = definitions.delete(:_suffix)
    enum_scopes = definitions.delete(:_scopes)

    default = {}
    default[:default] = definitions.delete(:_default) if definitions.key?(:_default)

    definitions.each do |name, values|
      assert_valid_enum_definition_values(values)
      # statuses = { }
      enum_values = ActiveSupport::HashWithIndifferentAccess.new
      name = name.to_s

      # def self.statuses() statuses end
      detect_enum_conflict!(name, name.pluralize, true)
      singleton_class.define_method(name.pluralize) { enum_values }
      defined_enums[name] = enum_values

      detect_enum_conflict!(name, name)
      detect_enum_conflict!(name, "#{name}=")

      attr = attribute_alias?(name) ? attribute_alias(name) : name

      attribute(attr, **default) do |subtype|
        subtype = subtype.subtype if EnumType === subtype
        EnumType.new(attr, enum_values, subtype)
      end

      value_method_names = []
      _enum_methods_module.module_eval do
        prefix = if enum_prefix == true
          "#{name}_"
        elsif enum_prefix
          "#{enum_prefix}_"
        end

        suffix = if enum_suffix == true
          "_#{name}"
        elsif enum_suffix
          "_#{enum_suffix}"
        end

        pairs = values.respond_to?(:each_pair) ? values.each_pair : values.each_with_index
        pairs.each do |label, value|
          enum_values[label] = value
          label = label.to_s

          value_method_name = "#{prefix}#{label}#{suffix}"
          value_method_names << value_method_name
          define_enum_methods(name, value_method_name, value, enum_scopes)

          method_friendly_label = label.gsub(/[\W&&[:ascii:]]+/, "_")
          value_method_alias = "#{prefix}#{method_friendly_label}#{suffix}"

          if value_method_alias != value_method_name && !value_method_names.include?(value_method_alias)
            value_method_names << value_method_alias
            define_enum_methods(name, value_method_alias, value, enum_scopes)
          end
        end
      end
      detect_negative_enum_conditions!(value_method_names) if enum_scopes != false
      enum_values.freeze
    end
  end
end
