module HTTParty
  # Exception raised when you attempt to set a non-existant format
  class UnsupportedFormat < StandardError; end

  # Exception raised when using a URI scheme other than HTTP or HTTPS
  class UnsupportedURIScheme < StandardError; end

  # Exception that is raised when request has redirected too many times
  class RedirectionTooDeep < StandardError; end
end
