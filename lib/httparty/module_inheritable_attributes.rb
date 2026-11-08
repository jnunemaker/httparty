# frozen_string_literal: true

module HTTParty
  module ModuleInheritableAttributes #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end

    # borrowed from Rails 3.2 ActiveSupport
    def self.hash_deep_dup(hash)
      case hash
      when Hash
        hash.each_with_object(hash.dup) do |(key, value), duplicate|
          duplicate[key] = hash_deep_dup(value)
        end
      when Array
        hash.map { |value| hash_deep_dup(value) }
      when Proc
        hash.dup
      else
        hash
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
                duplicate = ModuleInheritableAttributes.hash_deep_dup(#{ivar})
                #{ivar} = superclass.#{inheritable_attribute}.merge(duplicate)
              end
            RUBY
          end
        end
      end
    end
  end
end
