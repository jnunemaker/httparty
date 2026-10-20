# frozen_string_literal: true

module HTTParty
  module Utils
    def self.stringify_keys(hash)
      hash.transform_keys(&:to_s)
    end
  end
end
