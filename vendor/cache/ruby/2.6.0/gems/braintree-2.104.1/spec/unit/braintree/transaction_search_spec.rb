require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::TransactionSearch do
	it "overrides previous 'is' with new 'is' for the same field" do
		search = Braintree::TransactionSearch.new
		search.billing_company.is "one"
		search.billing_company.is "two"
		search.to_hash.should == {:billing_company => {:is => "two"}}
	end

	it "overrides previous 'in' with new 'in' for the same field" do
		search = Braintree::TransactionSearch.new
		search.status.in Braintree::Transaction::Status::Authorized
		search.status.in Braintree::Transaction::Status::SubmittedForSettlement
		search.to_hash.should == {:status => [Braintree::Transaction::Status::SubmittedForSettlement]}
	end

  it "raises if the operator 'is' is left off" do
    search = Braintree::TransactionSearch.new
    expect do
      search.billing_company "one"
    end.to raise_error(RuntimeError, "An operator is required")
  end
end
