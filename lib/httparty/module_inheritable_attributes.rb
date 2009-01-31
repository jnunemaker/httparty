module HTTParty
  module ModuleInheritableAttributes #:nodoc:
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
        @mattr_inheritable_attrs.each do |inheritable_attribute|
          instance_var = "@#{inheritable_attribute}" 
          subclass.instance_variable_set(instance_var, instance_variable_get(instance_var))
        end
      end
    end
  end
end