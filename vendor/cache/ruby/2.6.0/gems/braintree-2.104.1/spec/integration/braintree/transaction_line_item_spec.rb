require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require File.expand_path(File.dirname(__FILE__) + "/client_api/spec_helper")

describe Braintree::TransactionLineItem do
  describe "self.find_all" do
    it "returns line_items for the specified transaction" do
      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        },
        :line_items => [
          {
            :quantity => "1.0232",
            :name => "Name #1",
            :kind => "debit",
            :unit_amount => "45.1232",
            :total_amount => "45.15",
          },
        ],
      )
      result.success?.should == true
      transaction = result.transaction

      line_items = Braintree::TransactionLineItem.find_all(transaction.id)

      line_item = line_items[0]
      line_item.quantity.should == BigDecimal("1.0232")
      line_item.name.should == "Name #1"
      line_item.kind.should == "debit"
      line_item.unit_amount.should == BigDecimal("45.1232")
      line_item.total_amount.should == BigDecimal("45.15")
    end
  end
end

