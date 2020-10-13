require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::ApplePayCard do
  describe "bin" do
    it "returns Apple pay card bin" do
      Braintree::ApplePayCard._new(:gateway, bin: '411111').bin.should == '411111'
    end
  end

  describe "default?" do
    it "is true if the Apple pay card is the default payment method for the customer" do
      Braintree::ApplePayCard._new(:gateway, :default => true).default?.should == true
    end

    it "is false if the Apple pay card is not the default payment methodfor the customer" do
      Braintree::ApplePayCard._new(:gateway, :default => false).default?.should == false
    end
  end

  describe "expired?" do
    it "is true if the Apple pay card is expired" do
      Braintree::ApplePayCard._new(:gateway, :expired => true).expired?.should == true
    end

    it "is false if the Apple pay card is not expired" do
      Braintree::ApplePayCard._new(:gateway, :expired => false).expired?.should == false
    end
  end
end
