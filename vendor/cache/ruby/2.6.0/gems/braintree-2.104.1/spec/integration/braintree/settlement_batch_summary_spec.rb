# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + "/../../spec_helper")

describe Braintree::SettlementBatchSummary do
  describe "self.generate" do
    it "returns an empty collection if there is not data" do
      result = Braintree::SettlementBatchSummary.generate("1979-01-01")
      result.should be_success
      result.settlement_batch_summary.records.size.should be_zero
    end

    it "returns an error response if the date cannot be parsed" do
      result = Braintree::SettlementBatchSummary.generate("NOT A DATE :(")
      result.should_not be_success
      result.errors.for(:settlement_batch_summary).on(:settlement_date).map {|e| e.code}.should include(Braintree::ErrorCodes::SettlementBatchSummary::SettlementDateIsInvalid)
    end

    it "returns transactions settled on a given day" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::AmExes.first,
          :expiration_date => "05/2012",
          :cardholder_name => "Sergio Ramos"
        },
        :options => { :submit_for_settlement => true }
      )
      result = SpecHelper.settle_transaction transaction.id
      settlement_date = result[:transaction][:settlement_batch_id].split('_').first
      result = Braintree::SettlementBatchSummary.generate(settlement_date)

      result.should be_success
      amex_records = result.settlement_batch_summary.records.select {|row| row[:card_type] == Braintree::CreditCard::CardType::AmEx }
      amex_records.first[:count].to_i.should >= 1
      amex_records.first[:amount_settled].to_i.should >= Braintree::Test::TransactionAmounts::Authorize.to_i
    end

    it "can be grouped by a custom field" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::AmExes.first,
          :expiration_date => "05/2012",
          :cardholder_name => "Sergio Ramos"
        },
        :custom_fields => {
          :store_me => "1"
        },
        :options => { :submit_for_settlement => true }
      )
      result = SpecHelper.settle_transaction transaction.id
      settlement_date = result[:transaction][:settlement_batch_id].split('_').first
      result = Braintree::SettlementBatchSummary.generate(settlement_date, 'store_me')

      result.should be_success
      amex_records = result.settlement_batch_summary.records.select {|row| row[:store_me] == "1" }
      amex_records.should_not be_empty
      amex_records.first[:count].to_i.should >= 1
      amex_records.first[:amount_settled].to_i.should >= Braintree::Test::TransactionAmounts::Authorize.to_i
    end
  end
end
