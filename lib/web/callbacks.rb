module Web
  module Callbacks
    def callbacks
      @callbacks ||= Hash.new { |h,k| h[k] = [] }
    end
    
    def add_callback(name, &block)
      callbacks[name] << block
    end
    
    def run_callback(name, *args)
      args = args.first if args.size == 1
      callbacks[name].map { |block| block.call(args) }
    end
  end
end