require File.expand_path(File.dirname(__FILE__) + "/../../spec_helper")

describe Braintree::Disbursement do
  describe "transactions" do
    it "finds the transactions associated with the disbursement" do
      attributes = {
        :id => "123456",
        :merchant_account => {
          :id => "sandbox_sub_merchant_account",
          :master_merchant_account => {
            :id => "sandbox_master_merchant_account",
            :status => "active"
          },
          :status => "active"
        },
        :transaction_ids => ["sub_merchant_transaction"],
        :amount => "100.00",
        :disbursement_date => "2013-04-10",
        :exception_message => "invalid_account_number",
        :follow_up_action => "update",
        :retry => false,
        :success => false
      }

      disbursement = Braintree::Disbursement._new(Braintree::Configuration.gateway, attributes)
      disbursement.transactions.maximum_size.should == 1
      transaction = disbursement.transactions.first
      transaction.id.should == "sub_merchant_transaction"
    end
  end
end
