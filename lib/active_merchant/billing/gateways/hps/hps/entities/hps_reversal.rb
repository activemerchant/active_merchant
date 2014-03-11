module Hps
	class HpsReversal < HpsTransaction

		attr_accessor :avs_result_code, :avs_result_text, :cvv_result_code, :cvv_result_text, :cpc_indicator

		def initialize(header)
			super(header)
		end

	end
end