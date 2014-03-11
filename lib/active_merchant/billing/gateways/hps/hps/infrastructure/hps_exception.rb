module Hps
  class HpsException < StandardError
    
    attr_accessor :code, :inner_exception, :response_code, :response_text 
    
    
		def initialize(message, code, inner_exception = nil)

      @code=code
      @inner_exception = inner_exception
      super(message)

		end 

		def code
			if @code.nil? 
				"unknown" 
			else 
				@code 
			end
		end
		
    
  end 
end
