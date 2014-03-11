module Hps
	class HpsReportTransactionSummary < HpsTransaction

		attr_accessor :amount, :original_transaction_id, :masked_card_number, :transaction_type, :transaction_date, :exceptions

	end
end