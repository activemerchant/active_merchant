require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::PayPalAccount do
  before(:each) do
    @gateway = OpenStruct.new()
  end

  describe "token" do
    it "has a token identifier" do
      params = {:unknown_payment_method => {:token => 1234, :default => true}}
      Braintree::UnknownPaymentMethod.new(@gateway, params).token.should == 1234
    end
  end

  describe "image_url" do
    it "has a image_url" do
      params = {:unknown_payment_method => {:token => 1234, :default => true}}
      Braintree::UnknownPaymentMethod.new(@gateway, params).image_url.should == "https://assets.braintreegateway.com/payment_method_logo/unknown.png"
    end
  end

  describe "default?" do
    it "is true if the paypal account is the default payment method for the customer" do
      params = {:unknown_payment_method => {:token => 1234, :default => true}}
      Braintree::UnknownPaymentMethod.new(@gateway, params).should be_default
    end

    it "is false if the paypal account is not the default payment methodfor the customer" do
      params = {:unknown_payment_method => {:token => 1234, :default => false}}
      Braintree::UnknownPaymentMethod.new(@gateway, params).should_not be_default
    end
  end
end
