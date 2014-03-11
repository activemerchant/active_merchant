module Hps
  class InvalidRequestException < HpsException

  	attr_accessor :param

    def initialize(message, param = nil, code = nil)

    	@param = param
    	
      super(message, code)

    end

  end
end
