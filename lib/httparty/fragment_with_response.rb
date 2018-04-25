require 'delegate'

module HTTParty
  # Allow access to http_response and code by delegation on fragment
  class FragmentWithResponse < SimpleDelegator
    extend Forwardable

    def_delegator :@http_response, :code

    attr_reader :http_response

    def initialize(fragment, http_response)
      @fragment = fragment
      @http_response = http_response
      super fragment
    end
  end
end
