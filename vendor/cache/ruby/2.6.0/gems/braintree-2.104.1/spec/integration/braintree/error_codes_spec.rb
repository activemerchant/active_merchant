require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::ErrorCodes do
  describe Braintree::ErrorCodes::CreditCard do
    it "returns CardholderNameIsTooLong when cardholder name is too long" do
      result = Braintree::Customer.create(
        :credit_card => {
          :cardholder_name => "x" * 256
        }
      )
      result.success?.should == false
      result.errors.for(:customer).for(:credit_card).map { |e| e.code }.should \
        include(Braintree::ErrorCodes::CreditCard::CardholderNameIsTooLong)
    end
  end
end
