module Hps

	class HpsTransaction

		attr_accessor :transaction_header, :transaction_id, :response_code, :response_text, :reference_number

		def initialize(transaction_header=nil)
			@transaction_header = transaction_header
		end

	end

	def self.transaction_type_to_service_name(transaction_type)

		case transaction_type

		when Hps::HpsTransactionType::AUTHORIZE
			Hps::ItemChoiceTypePosResponseVer10Transaction::CreditAuth

		when Hps::HpsTransactionType::CAPTURE
			Hps::ItemChoiceTypePosResponseVer10Transaction::CreditAddToBatch

		when Hps::HpsTransactionType::CHARGE
			Hps::ItemChoiceTypePosResponseVer10Transaction::CreditSale

		when Hps::HpsTransactionType::REFUND
			Hps::ItemChoiceTypePosResponseVer10Transaction::CreditReturn

		when Hps::HpsTransactionType::REVERSE
			Hps::ItemChoiceTypePosResponseVer10Transaction::CreditReversal

		when Hps::HpsTransactionType::VERIFY
			Hps::ItemChoiceTypePosResponseVer10Transaction::CreditAccountVerify

		when Hps::HpsTransactionType::LIST
			Hps::ItemChoiceTypePosResponseVer10Transaction::ReportActivity

		when Hps::HpsTransactionType::GET
			Hps::ItemChoiceTypePosResponseVer10Transaction::ReportTxnDetail

		when Hps::HpsTransactionType::VOID
			Hps::ItemChoiceTypePosResponseVer10Transaction::CreditVoid

		when Hps::HpsTransactionType::BATCH_CLOSE
			Hps::ItemChoiceTypePosResponseVer10Transaction::BatchClose

		when Hps::HpsTransactionType::SECURITY_ERROR
			"SecurityError"
		else
			""				
		end

	end

	def self.service_name_to_transaction_type(service_name)

		if service_name == Hps::ItemChoiceTypePosResponseVer10Transaction::CreditAuth
			Hps::HpsTransactionType::AUTHORIZE	

		elsif service_name == Hps::ItemChoiceTypePosResponseVer10Transaction::CreditAddToBatch
			 Hps::HpsTransactionType::CAPTURE

		elsif service_name == Hps::ItemChoiceTypePosResponseVer10Transaction::CreditSale
			Hps::HpsTransactionType::CHARGE

		elsif service_name == Hps::ItemChoiceTypePosResponseVer10Transaction::CreditReturn
			Hps::HpsTransactionType::REFUND

		elsif service_name == Hps::ItemChoiceTypePosResponseVer10Transaction::CreditReversal
			Hps::HpsTransactionType::REVERSE

		elsif service_name == Hps::ItemChoiceTypePosResponseVer10Transaction::CreditAccountVerify
			Hps::HpsTransactionType::VERIFY

		elsif service_name == Hps::ItemChoiceTypePosResponseVer10Transaction::ReportActivity
			Hps::HpsTransactionType::LIST

		elsif service_name == Hps::ItemChoiceTypePosResponseVer10Transaction::ReportTxnDetail
			Hps::HpsTransactionType::GET

		elsif service_name == Hps::ItemChoiceTypePosResponseVer10Transaction::CreditVoid
			Hps::HpsTransactionType::Void

		elsif service_name == Hps::ItemChoiceTypePosResponseVer10Transaction::BatchClose
			Hps::HpsTransactionType::BATCH_CLOSE

		elsif service_name == "SecurityError"
			Hps::HpsTransactionType::SECURITY_ERROR
		else
			nil				
		end

	end

	module ItemChoiceTypePosResponseVer10Transaction

		AddAttachment = "AddAttachment"
	  Authenticate = "Authenticate"
	  BatchClose = "BatchClose"
	  CancelImpersonation = "CancelImpersonation"
	  CheckSale = "CheckSale"
	  CheckVoid = "CheckVoid"
	  CreditAccountVerify = "CreditAccountVerify"
	  CreditAddToBatch = "CreditAddToBatch"
	  CreditAuth = "CreditAuth"
	  CreditCPCEdit = "CreditCPCEdit"
	  CreditIncrementalAuth = "CreditIncrementalAuth"
	  CreditOfflineAuth = "CreditOfflineAuth"
	  CreditOfflineSale = "CreditOfflineSale"
	  CreditReturn = "CreditReturn"
	  CreditReversal = "CreditReversal"
	  CreditSale = "CreditSale"
	  CreditTxnEdit = "CreditTxnEdit"
	  CreditVoid = "CreditVoid"
	  DebitAddValue = "DebitAddValue"
	  DebitReturn = "DebitReturn"
	  DebitReversal = "DebitReversal"
	  DebitSale = "DebitSale"
	  EBTBalanceInquiry = "EBTBalanceInquiry"
	  EBTCashBackPurchase = "EBTCashBackPurchase"
	  EBTCashBenefitWithdrawal = "EBTCashBenefitWithdrawal"
	  EBTFSPurchase = "EBTFSPurchase"
	  EBTFSReturn = "EBTFSReturn"
	  EBTVoucherPurchase = "EBTVoucherPurchase"
	  EndToEndTest = "EndToEndTest"
	  FindTransactions = "FindTransactions"
	  GetAttachments = "GetAttachments"
	  GetUserDeviceSettings = "GetUserDeviceSettings"
	  GetUserSettings = "GetUserSettings"
	  GiftCardActivate = "GiftCardActivate"
	  GiftCardAddValue = "GiftCardAddValue"
	  GiftCardBalance = "GiftCardBalance"
	  GiftCardCurrentDayTotals = "GiftCardCurrentDayTotals"
	  GiftCardDeactivate = "GiftCardDeactivate"
	  GiftCardPreviousDayTotals = "GiftCardPreviousDayTotals"
	  GiftCardReplace = "GiftCardReplace"
	  GiftCardReversal = "GiftCardReversal"
	  GiftCardSale = "GiftCardSale"
	  GiftCardVoid = "GiftCardVoid"
	  Impersonate = "Impersonate"
	  InvalidateAuthentication = "InvalidateAuthentication"
	  ManageSettings = "ManageSettings"
	  ManageUsers = "ManageUsers"
	  PrePaidAddValue = "PrePaidAddValue"
	  PrePaidBalanceInquiry = "PrePaidBalanceInquiry"
	  RecurringBilling = "RecurringBilling"
	  ReportActivity = "ReportActivity"
	  ReportBatchDetail = "ReportBatchDetail"
	  ReportBatchHistory = "ReportBatchHistory"
	  ReportBatchSummary = "ReportBatchSummary"
	  ReportOpenAuths = "ReportOpenAuths"
	  ReportSearch = "ReportSearch"
	  ReportTxnDetail = "ReportTxnDetail"
	  SendReceipt = "SendReceipt"
	  TestCredentials = "TestCredentials"

	end


end

