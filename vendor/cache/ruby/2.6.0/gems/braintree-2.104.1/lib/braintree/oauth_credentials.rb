module Braintree
  class OAuthCredentials
    include BaseModule # :nodoc:

    attr_reader :access_token
    attr_reader :expires_at
    attr_reader :refresh_token
    attr_reader :token_type

    def initialize(attributes) # :nodoc:
      set_instance_variables_from_hash(attributes)
    end

    class << self
      protected :new
    end

    def self._new(*args) # :nodoc:
      self.new *args
    end
  end
end
