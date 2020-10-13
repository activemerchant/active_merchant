require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::PayPalAccount do
  describe "self.create" do
    it "raises an exception if attributes contain an invalid key" do
      expect do
        result = Braintree::PayPalAccount.create(
          :invalid_key => "bad stuff",
          :options => {
            :invalid_option => "bad option",
          }
        )
      end.to raise_error(ArgumentError, "invalid keys: invalid_key, options[invalid_option]")
    end
  end

  describe "self.update" do
    it "raises an exception if attributes contain an invalid key" do
      expect do
        Braintree::PayPalAccount.update("some_token", :invalid_key => 'val')
      end.to raise_error(ArgumentError, "invalid keys: invalid_key")
    end
  end

  describe "default?" do
    it "is true if the paypal account is the default payment method for the customer" do
      Braintree::PayPalAccount._new(:gateway, :default => true).default?.should == true
    end

    it "is false if the paypal account is not the default payment methodfor the customer" do
      Braintree::PayPalAccount._new(:gateway, :default => false).default?.should == false
    end
  end

  describe "timestamps" do
    it "exposes created_at and updated_at" do
      now = Time.now
      paypal_account = Braintree::PayPalAccount._new(:gateway, :updated_at => now, :created_at => now)

      paypal_account.created_at.should == now
      paypal_account.updated_at.should == now
    end
  end
end
