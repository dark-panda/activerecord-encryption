# frozen_string_literal: true

# Backport of fix for https://github.com/rails/rails/issues/41138
ActiveRecord::Attributes::ClassMethods.instance_eval do
  def attribute(name, cast_type = nil, default: NO_DEFAULT_PROVIDED, **options, &block)
    name = name.to_s
    reload_schema_from_cache

    case cast_type
    when Symbol
      type = cast_type
      cast_type = -> _ { Type.lookup(type, **options, adapter: Type.adapter_name_from(self)) }
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
