module HTTParty
  module ModuleInheritableAttributes #:nodoc:

    def self.deep_clone(value)
      if value.is_a?(Hash)
        value.inject({}) do |result, (k, v)|
          result[k] = deep_clone(v)
          result
        end
      elsif value.is_a?(Proc)
        value # We can't serialize procs
      elsif value.respond_to?(:map)
        value.map { |value| deep_clone value }
      else
        # Other objects - use the default marshal dump / load strategy.
        Marshal.load(Marshal.dump(value))
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods #:nodoc:
      def mattr_inheritable(*args)
        @mattr_inheritable_attrs ||= [:mattr_inheritable_attrs]
        @mattr_inheritable_attrs += args
        args.each do |arg|
          module_eval %(class << self; attr_accessor :#{arg} end)
        end
        @mattr_inheritable_attrs
      end

      def inherited(subclass)
        super
        @mattr_inheritable_attrs.each do |inheritable_attribute|
          ivar = "@#{inheritable_attribute}"
          subclass.instance_variable_set(ivar, instance_variable_get(ivar).clone)
          if instance_variable_get(ivar).respond_to?(:merge)
            method = <<-EOM
              def self.#{inheritable_attribute}
                #{ivar} = superclass.#{inheritable_attribute}.merge HTTParty::ModuleInheritableAttributes.deep_clone(#{ivar})
              end
            EOM
            subclass.class_eval method
          end
        end
      end

    end
  end
end
