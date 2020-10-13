require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::SuccessfulResult do
  describe "initialize" do
    it "sets instance variables from the values in the hash" do
      result = Braintree::SuccessfulResult.new(
        :transaction => "transaction_value",
        :credit_card => "credit_card_value"
      )
      result.success?.should == true
      result.transaction.should == "transaction_value"
      result.credit_card.should == "credit_card_value"
    end

    it "can be initialized without any values" do
      result = Braintree::SuccessfulResult.new
      result.success?.should == true
    end
  end

  describe "inspect" do
    it "is pretty" do
      result = Braintree::SuccessfulResult.new(:transaction => "transaction_value")
      result.inspect.should == "#<Braintree::SuccessfulResult transaction:\"transaction_value\">"
    end
  end
end
