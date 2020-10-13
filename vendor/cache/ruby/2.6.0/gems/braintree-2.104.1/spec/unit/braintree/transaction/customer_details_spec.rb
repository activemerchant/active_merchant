require File.expand_path(File.dirname(__FILE__) + "/../../spec_helper")

describe Braintree::Transaction::CustomerDetails do
  describe "inspect" do
    it "inspects" do
      details = Braintree::Transaction::CustomerDetails.new(
        :id => "id",
        :first_name => "Amy",
        :last_name => "Smith",
        :email => "amy.smith@example.com",
        :company => "Smith Co.",
        :website => "http://www.example.com",
        :phone => "6145551234",
        :fax => "3125551234"
      )
      details.inspect.should == %(#<id: "id", first_name: "Amy", last_name: "Smith", email: "amy.smith@example.com", company: "Smith Co.", website: "http://www.example.com", phone: "6145551234", fax: "3125551234">)
    end
  end
end
