module Hps
	module SdkCodes

		def self.invalid_transaction_id
			"0"
		end

		def self.invalid_gateway_url
			"1"
		end

		def self.unable_to_process_transaction
			"2"
		end

		def self.invalid_start_date
			"3"
		end

		def self.invalid_end_date
			"4"
		end

		def self.missing_currency
			"5"
		end

		def self.invalid_currency
			"6"
		end

		def self.invalid_amount
			"7"
		end

		def self.reversal_error_after_gateway_timeout
			"8"
		end

		def self.reversal_error_after_issuer_timeout
			"9"
		end

		def self.processing_error
			"10"
		end

	end
end