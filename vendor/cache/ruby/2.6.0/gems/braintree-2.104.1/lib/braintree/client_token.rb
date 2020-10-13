require 'json'

module Braintree
  module ClientToken
    DEFAULT_VERSION = 2

    def self.generate(*args)
      Configuration.gateway.client_token.generate(*args)
    end
  end
end
