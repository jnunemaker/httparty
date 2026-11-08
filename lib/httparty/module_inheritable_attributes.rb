# frozen_string_literal: true

module HTTParty
  module ModuleInheritableAttributes #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end

    # borrowed from Rails 3.2 ActiveSupport
    def self.hash_deep_dup(object)
      case object
      when Hash
        object.each_with_object(object.dup) do |(key, value), duplicate|
          duplicate[key] = hash_deep_dup(value)
        end
      when Array
        copy = object.dup.map! { |value| hash_deep_dup(value) }
        object.frozen? ? copy.freeze : copy
      when Proc
        object.dup
      else
        object
      end
    end

    module ClassMethods #:nodoc:
      def mattr_inheritable(*args)
        @mattr_inheritable_attrs ||= [:mattr_inheritable_attrs]
        @mattr_inheritable_attrs += args

        args.each do |arg|
          singleton_class.attr_accessor(arg)
        end

        @mattr_inheritable_attrs
      end

      def inherited(subclass)
        super
        @mattr_inheritable_attrs.each do |inheritable_attribute|
          ivar = :"@#{inheritable_attribute}"
          subclass.instance_variable_set(ivar, instance_variable_get(ivar).clone)

          if instance_variable_get(ivar).respond_to?(:merge)
            subclass.class_eval <<~RUBY, __FILE__, __LINE__ + 1
              def self.#{inheritable_attribute}
                duplicate = superclass.#{inheritable_attribute}.merge(#{ivar})
                #{ivar} = ModuleInheritableAttributes.hash_deep_dup(duplicate)
              end
            RUBY
          end
        end
      end
    end
  end
end
