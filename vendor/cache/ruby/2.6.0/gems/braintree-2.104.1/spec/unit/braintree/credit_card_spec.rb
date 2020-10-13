require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::CreditCard do
  describe "self.create" do
    it "raises an exception if attributes contain an invalid key" do
      expect do
        Braintree::CreditCard.create(:invalid_key => 'val')
      end.to raise_error(ArgumentError, "invalid keys: invalid_key")
    end
  end

  describe "self.create_signature" do
    it "should be what we expect" do
      Braintree::CreditCardGateway._create_signature.should == [
        :billing_address_id,
        :cardholder_name,
        :cvv,
        :device_session_id,
        :expiration_date,
        :expiration_month,
        :expiration_year,
        :number,
        :token,
        :venmo_sdk_payment_method_code,
        :device_data,
        :fraud_merchant_id,
        :payment_method_nonce,
        {:external_vault=>[:network_transaction_id]},
        {:options => [:make_default, :verification_merchant_account_id, :verify_card, :verification_amount, :venmo_sdk_session, :fail_on_duplicate_payment_method, :verification_account_type]},
        {:billing_address => [
          :company,
          :country_code_alpha2,
          :country_code_alpha3,
          :country_code_numeric,
          :country_name,
          :extended_address,
          :first_name,
          :last_name,
          :locality,
          :phone_number,
          :postal_code,
          :region,
          :street_address
        ]},
        {:three_d_secure_pass_thru => [
          :eci_flag,
          :cavv,
          :xid,
          :three_d_secure_version,
          :authentication_response,
          :directory_response,
          :cavv_algorithm,
          :ds_transaction_id,
        ]},
        :customer_id,
      ]
    end
  end

  describe "self.update_signature" do
    it "should be what we expect" do
      Braintree::CreditCardGateway._update_signature.should == [
        :billing_address_id,
        :cardholder_name,
        :cvv,
        :device_session_id,
        :expiration_date,
        :expiration_month,
        :expiration_year,
        :number,
        :token,
        :venmo_sdk_payment_method_code,
        :device_data,
        :fraud_merchant_id,
        :payment_method_nonce,
        {:external_vault=>[:network_transaction_id]},
        {:options => [:make_default, :verification_merchant_account_id, :verify_card, :verification_amount, :venmo_sdk_session, :fail_on_duplicate_payment_method, :verification_account_type]},
        {:billing_address => [
          :company,
          :country_code_alpha2,
          :country_code_alpha3,
          :country_code_numeric,
          :country_name,
          :extended_address,
          :first_name,
          :last_name,
          :locality,
          :phone_number,
          :postal_code,
          :region,
          :street_address,
          {:options => [:update_existing]}
        ]},
        {:three_d_secure_pass_thru => [
          :eci_flag,
          :cavv,
          :xid,
          :three_d_secure_version,
          :authentication_response,
          :directory_response,
          :cavv_algorithm,
          :ds_transaction_id,
        ]},
      ]
    end
  end

  describe "self.create_from_transparent_redirect" do
    it "raises an exception if the query string is forged" do
      expect do
        Braintree::CreditCard.create_from_transparent_redirect("http_status=200&forged=query_string")
      end.to raise_error(Braintree::ForgedQueryString)
    end
  end

  describe "self.create_credit_card_url" do
    it "returns the url" do
      config = Braintree::Configuration.instantiate
      Braintree::CreditCard.create_credit_card_url.should == "http#{config.ssl? ? 's' : ''}://#{config.server}:#{config.port}/merchants/integration_merchant_id/payment_methods/all/create_via_transparent_redirect_request"
    end
  end

  describe "==" do
    it "returns true if given a credit card with the same token" do
      first = Braintree::CreditCard._new(:gateway, :token => 123)
      second = Braintree::CreditCard._new(:gateway, :token => 123)

      first.should == second
      second.should == first
    end

    it "returns false if given a credit card with a different token" do
      first = Braintree::CreditCard._new(:gateway, :token => 123)
      second = Braintree::CreditCard._new(:gateway, :token => 124)

      first.should_not == second
      second.should_not == first
    end

    it "returns false if not given a credit card" do
      credit_card = Braintree::CreditCard._new(:gateway, :token => 123)
      credit_card.should_not == "not a credit card"
    end
  end

  describe "default?" do
    it "is true if the credit card is the default credit card for the customer" do
      Braintree::CreditCard._new(:gateway, :default => true).default?.should == true
    end

    it "is false if the credit card is not the default credit card for the customer" do
      Braintree::CreditCard._new(:gateway, :default => false).default?.should == false
    end
  end

  describe "self.find" do
    it "raises error if passed empty string" do
      expect do
        Braintree::CreditCard.find("")
      end.to raise_error(ArgumentError)
    end

    it "raises error if passed invalid string" do
      expect do
        Braintree::CreditCard.find("\t")
      end.to raise_error(ArgumentError)
    end

    it "raises error if passed nil" do
      expect do
        Braintree::CreditCard.find(nil)
      end.to raise_error(ArgumentError)
    end

    it "does not raise an error if address_id does not respond to strip" do
      Braintree::Http.stub(:new).and_return double.as_null_object
      expect do
        Braintree::CreditCard.find(8675309)
      end.to_not raise_error
    end
  end

  describe "inspect" do
    it "includes the token first" do
      output = Braintree::CreditCard._new(:gateway, :token => "cc123").inspect
      output.should include("#<Braintree::CreditCard token: \"cc123\",")
    end

    it "includes all customer attributes" do
      credit_card = Braintree::CreditCard._new(
        :gateway,
        :bin => "411111",
        :card_type => "Visa",
        :cardholder_name => "John Miller",
        :created_at => Time.now,
        :customer_id => "cid1",
        :expiration_month => "01",
        :expiration_year => "2020",
        :last_4 => "1111",
        :token => "tok1",
        :updated_at => Time.now,
        :is_network_tokenized => false,
      )
      output = credit_card.inspect
      output.should include(%q(bin: "411111"))
      output.should include(%q(card_type: "Visa"))
      output.should include(%q(cardholder_name: "John Miller"))

      output.should include(%q(customer_id: "cid1"))
      output.should include(%q(expiration_month: "01"))
      output.should include(%q(expiration_year: "2020"))
      output.should include(%q(last_4: "1111"))
      output.should include(%q(token: "tok1"))
      output.should include(%Q(updated_at: #{credit_card.updated_at.inspect}))
      output.should include(%Q(created_at: #{credit_card.created_at.inspect}))
      output.should include(%q(is_network_tokenized?: false))
    end
  end

  describe "masked_number" do
    it "uses the bin and last_4 to build the masked number" do
      credit_card = Braintree::CreditCard._new(
        :gateway,
        :bin => "510510",
        :last_4 => "5100"
      )
      credit_card.masked_number.should == "510510******5100"
    end
  end

  describe "is_network_tokenized?" do
    it "returns true" do
      credit_card = Braintree::CreditCard._new(
        :gateway,
        :bin => "510510",
        :last_4 => "5100",
        :is_network_tokenized => true
      )
      credit_card.is_network_tokenized?.should == true
    end

    it "returns false" do
      credit_card = Braintree::CreditCard._new(
        :gateway,
        :bin => "510510",
        :last_4 => "5100",
        :is_network_tokenized => false
      )
      credit_card.is_network_tokenized?.should == false
    end
  end

  describe "self.update" do
    it "raises an exception if attributes contain an invalid key" do
      expect do
        Braintree::CreditCard._new(Braintree::Configuration.gateway, {}).update(:invalid_key => 'val')
      end.to raise_error(ArgumentError, "invalid keys: invalid_key")
    end
  end

  describe "self.new" do
    it "is protected" do
      expect do
        Braintree::CreditCard.new
      end.to raise_error(NoMethodError, /protected method .new/)
    end
  end

  describe "self._new" do
    describe "initializing verification" do
      it "picks the youngest verification" do
        verification1 = { :created_at => Time.now, :id => 123 }
        verification2 = { :created_at => Time.now - 3600, :id => 456 }
        credit_card = Braintree::CreditCard._new(Braintree::Configuration.gateway, {:verifications => [verification1, verification2]})
        credit_card.verification.id.should == 123
      end

      it "picks nil if verifications are empty" do
        credit_card = Braintree::CreditCard._new(Braintree::Configuration.gateway, {})
        credit_card.verification.should be_nil
      end
    end
  end
end
