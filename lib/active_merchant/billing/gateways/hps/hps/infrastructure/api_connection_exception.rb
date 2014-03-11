module Hps
  class ApiConnectionException < HpsException

    def initialize(message, inner_exception, code)

      super(message, code, inner_exception)

    end
    
  end
end
