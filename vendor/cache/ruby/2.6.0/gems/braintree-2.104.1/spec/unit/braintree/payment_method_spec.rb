require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::PaymentMethod do
  describe "find" do
    it "handles an unknown payment method type" do
      unknown_response = {:unknown_payment_method => {:token => 1234, :default => true}}
      http_instance = double(:get => unknown_response)
      Braintree::Http.stub(:new).and_return(http_instance)
      unknown_payment_method = Braintree::PaymentMethod.find("UNKNOWN_PAYMENT_METHOD_TOKEN")

      unknown_payment_method.token.should == 1234
      unknown_payment_method.default?.should be(true)
    end
  end

  describe "update" do
    it "handles an unknown payment method type" do
      unknown_response = {:unknown_payment_method => {:token => 1234, :default => true}}
      http_instance = double(:put => unknown_response)
      Braintree::Http.stub(:new).and_return(http_instance)
      result = Braintree::PaymentMethod.update(:unknown,
        {:options => {:make_default => true}})

      result.should be_success
      result.payment_method.token.should == 1234
      result.payment_method.should be_instance_of(Braintree::UnknownPaymentMethod)
    end
  end

  describe "delete" do
    let(:http_stub) { double('http_stub').as_null_object }
    it "accepts revoke_all_grants option with value true" do
      Braintree::Http.stub(:new).and_return http_stub
      http_stub.should_receive(:delete).with("/merchants/integration_merchant_id/payment_methods/any/some_token?revoke_all_grants=true")
      Braintree::PaymentMethod.delete("some_token", {:revoke_all_grants => true})
    end

    it "accepts revoke_all_grants option with value false" do
      Braintree::Http.stub(:new).and_return http_stub
      http_stub.should_receive(:delete).with("/merchants/integration_merchant_id/payment_methods/any/some_token?revoke_all_grants=false")
      Braintree::PaymentMethod.delete("some_token", {:revoke_all_grants => false})
    end

    it "throws error when an invalid param is used for options" do
      expect do
        Braintree::PaymentMethod.delete("some_token", {:invalid_key => false})
      end.to raise_error(ArgumentError)
    end

    it "accepts just the token, revoke_all_grants is optional" do
      Braintree::Http.stub(:new).and_return http_stub
      http_stub.should_receive(:delete).with("/merchants/integration_merchant_id/payment_methods/any/some_token")
      Braintree::PaymentMethod.delete("some_token")
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

  describe "self.grant" do
    it "raises error if passed empty string" do
      expect do
        Braintree::PaymentMethod.grant("")
      end.to raise_error(ArgumentError)
    end

    it "raises error if passed invalid string" do
      expect do
        Braintree::PaymentMethod.grant("\t", false)
      end.to raise_error(ArgumentError)
    end

    it "raises error if passed nil" do
      expect do
        Braintree::PaymentMethod.grant(nil, false)
      end.to raise_error(ArgumentError)
    end

    it "does not raise an error if token does not respond to strip" do
      Braintree::Http.stub(:new).and_return double.as_null_object
      expect do
        Braintree::PaymentMethod.grant(8675309, :allow_vaulting => false)
      end.to_not raise_error
    end

    it "accepts all options as hash map" do
      Braintree::Http.stub(:new).and_return double.as_null_object
      expect do
        Braintree::PaymentMethod.grant("$dummyToken", :allow_vaulting => false, :include_billing_postal_code => true)
      end.to_not raise_error
    end

    it "accepts only token as parameter" do
      Braintree::Http.stub(:new).and_return double.as_null_object
      expect do
        Braintree::PaymentMethod.grant("$dummyToken")
      end.to_not raise_error
    end

  end

  describe "self.revoke" do
    it "raises error if passed empty string" do
      expect do
        Braintree::PaymentMethod.revoke("")
      end.to raise_error(ArgumentError)
    end

    it "raises error if passed invalid string" do
      expect do
        Braintree::PaymentMethod.revoke("\t")
      end.to raise_error(ArgumentError)
    end

    it "raises error if passed nil" do
      expect do
        Braintree::PaymentMethod.revoke(nil)
      end.to raise_error(ArgumentError)
    end

    it "does not raise an error if token does not respond to strip" do
      Braintree::Http.stub(:new).and_return double.as_null_object
      expect do
        Braintree::PaymentMethod.revoke(8675309)
      end.to_not raise_error
    end
  end
end
