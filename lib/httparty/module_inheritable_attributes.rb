module HTTParty
  module ModuleInheritableAttributes #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end

    # borrowed from Rails 3.2 ActiveSupport
    def self.hash_deep_dup(h)
      duplicate = h.dup
      duplicate.each_pair do |k,v|
        tv = duplicate[k]
        duplicate[k] = tv.is_a?(Hash) && v.is_a?(Hash) ? hash_deep_dup(tv) : v
      end
      duplicate
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
                #{ivar} = superclass.#{inheritable_attribute}.merge ModuleInheritableAttributes.hash_deep_dup(#{ivar})
              end
            EOM
            subclass.class_eval method
          end
        end
      end
    end
  end
end
