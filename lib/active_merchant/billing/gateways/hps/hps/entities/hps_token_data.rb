module Hps
	class HpsTokenData

		attr_accessor :token_value, :response_code, :response_message

		def initialize(response_message = nil)
			@response_message = response_message			
		end

	end
end