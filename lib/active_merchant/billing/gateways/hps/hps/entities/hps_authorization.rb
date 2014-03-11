module Hps
	class HpsAuthorization < HpsTransaction

		attr_accessor :avs_result_code, :avs_result_text, :cvv_result_code, 
									:cvv_result_text, :cpc_indicator, :authorization_code, 
									:authorized_amount, :card_type, :token_data

		def initialize(header)
			super(header)
		end
									
	end
end