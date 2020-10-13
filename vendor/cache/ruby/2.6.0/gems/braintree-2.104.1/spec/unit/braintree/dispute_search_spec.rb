require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::DisputeSearch do
  it "overrides previous 'is' with new 'is' for the same field" do
    search = Braintree::DisputeSearch.new
    search.id.is "dispute1"
    search.id.is "dispute2"
    search.to_hash.should == {:id => {:is => "dispute2"}}
  end

  it "overrides previous 'in' with new 'in' for the same field" do
    search = Braintree::DisputeSearch.new
    search.status.in Braintree::Dispute::Status::Open
    search.status.in Braintree::Dispute::Status::Won
    search.to_hash.should == {:status => [Braintree::Dispute::Status::Won]}
  end

  [
    :amount_disputed,
    :amount_won,
    :case_number,
    :customer_id,
    :disbursement_date,
    :effective_date,
    :id,
    :merchant_account_id,
    :reason_code,
    :received_date,
    :reference_number,
    :reply_by_date,
    :transaction_id,
    :transaction_source,
  ].each do |field|
    it "allows searching on #{field}" do
      search = Braintree::DisputeSearch.new

      expect do
        search.send(field).is "hello"
      end.not_to raise_error
    end
  end

  [
    :kind,
    :reason,
    :status,
  ].each do |field|
    it "raises if provided an unknown #{field} value" do
      search = Braintree::DisputeSearch.new
      expect do
        search.send(field).is "unknown value"
      end.to raise_error(/Invalid argument/)
    end
  end

  it "raises if no operator is provided" do
    search = Braintree::DisputeSearch.new
    expect do
      search.id "one"
    end.to raise_error(RuntimeError, "An operator is required")
  end
end
