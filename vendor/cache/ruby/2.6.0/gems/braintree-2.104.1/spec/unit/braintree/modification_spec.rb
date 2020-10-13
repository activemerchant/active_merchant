require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::Modification do
  it "converts string amount" do
    Braintree::Modification._new(:amount => "100.00").amount.should == BigDecimal("100.00")
  end
end
