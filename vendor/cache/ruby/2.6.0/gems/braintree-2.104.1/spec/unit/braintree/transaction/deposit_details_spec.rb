require File.expand_path(File.dirname(__FILE__) + "/../../spec_helper")

describe Braintree::Transaction::DisbursementDetails do
  describe "valid?" do
    it "returns true if disbursement details are initialized" do
      details = Braintree::Transaction::DisbursementDetails.new(
        :disbursement_date => Date.new(2013, 4, 1)
      )
      details.valid?.should == true
    end
    it "returns true if disbursement details are initialized" do
      details = Braintree::Transaction::DisbursementDetails.new(
        :disbursement_date => nil
      )
      details.valid?.should == false
    end
  end
end
