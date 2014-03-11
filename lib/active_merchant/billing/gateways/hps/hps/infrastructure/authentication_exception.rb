module Hps
  class AuthenticationException < HpsException

    def initialize(message)

      super(message, nil)

    end
    
  end
end
