require File.expand_path(File.dirname(__FILE__) + "/../../spec_helper")
require File.expand_path(File.dirname(__FILE__) + "/spec_helper")


describe Braintree::ClientToken do
  describe "self.generate" do
    it "generates a fingerprint that the gateway accepts" do
      config = Braintree::Configuration.instantiate
      raw_client_token = Braintree::ClientToken.generate
      client_token = decode_client_token(raw_client_token)
      http = ClientApiHttp.new(
        config,
        :authorization_fingerprint => client_token["authorizationFingerprint"],
        :shared_customer_identifier => "fake_identifier",
        :shared_customer_identifier_type => "testing"
      )

      response = http.get_payment_methods

      response.code.should == "200"
    end

    it "raises ArgumentError on invalid parameters (422)" do
      expect do
        Braintree::ClientToken.generate(:options => {:make_default => true})
      end.to raise_error(ArgumentError)
    end

    describe "version" do
      it "allows a client token version to be specified" do
        config = Braintree::Configuration.instantiate
        client_token_string = Braintree::ClientToken.generate(:version => 1)
        client_token = JSON.parse(client_token_string)
        client_token["version"].should == 1
      end

      it "defaults to 2" do
        config = Braintree::Configuration.instantiate
        client_token_string = Braintree::ClientToken.generate
        client_token = decode_client_token(client_token_string)
        client_token["version"].should == 2
      end
    end

    it "can pass verify_card" do
      config = Braintree::Configuration.instantiate
      result = Braintree::Customer.create
      raw_client_token = Braintree::ClientToken.generate(
        :customer_id => result.customer.id,
        :options => {
          :verify_card => true
        }
      )
      client_token = decode_client_token(raw_client_token)

      http = ClientApiHttp.new(
        config,
        :authorization_fingerprint => client_token["authorizationFingerprint"],
        :shared_customer_identifier => "fake_identifier",
        :shared_customer_identifier_type => "testing"
      )

      response = http.add_payment_method(
        :credit_card => {
          :number => "4000111111111115",
          :expiration_month => "11",
          :expiration_year => "2099"
        }
      )

      response.code.should == "422"
    end

    it "can pass make_default" do
      config = Braintree::Configuration.instantiate
      result = Braintree::Customer.create
      customer_id = result.customer.id
      raw_client_token = Braintree::ClientToken.generate(
        :customer_id => customer_id,
        :options => {
          :make_default => true
        }
      )
      client_token = decode_client_token(raw_client_token)

      http = ClientApiHttp.new(
        config,
        :authorization_fingerprint => client_token["authorizationFingerprint"],
        :shared_customer_identifier => "fake_identifier",
        :shared_customer_identifier_type => "testing"
      )

      response = http.add_payment_method(
        :credit_card => {
          :number => "4111111111111111",
          :expiration_month => "11",
          :expiration_year => "2099"
        }
      )

      response.code.should == "201"

      response = http.add_payment_method(
        :credit_card => {
          :number => "4005519200000004",
          :expiration_month => "11",
          :expiration_year => "2099"
        }
      )

      response.code.should == "201"

      customer = Braintree::Customer.find(customer_id)
      customer.credit_cards.select { |c| c.bin == "400551" }[0].should be_default
    end

    it "can pass fail_on_duplicate_payment_method" do
      config = Braintree::Configuration.instantiate
      result = Braintree::Customer.create
      customer_id = result.customer.id
      raw_client_token = Braintree::ClientToken.generate(
        :customer_id => customer_id
      )
      client_token = decode_client_token(raw_client_token)

      http = ClientApiHttp.new(
        config,
        :authorization_fingerprint => client_token["authorizationFingerprint"],
        :shared_customer_identifier => "fake_identifier",
        :shared_customer_identifier_type => "testing"
      )

      response = http.add_payment_method(
        :credit_card => {
          :number => "4111111111111111",
          :expiration_month => "11",
          :expiration_year => "2099"
        }
      )

      response.code.should == "201"

      second_raw_client_token = Braintree::ClientToken.generate(
        :customer_id => customer_id,
        :options => {
          :fail_on_duplicate_payment_method => true
        }
      )
      second_client_token = decode_client_token(second_raw_client_token)

      http.fingerprint = second_client_token["authorizationFingerprint"]

      response = http.add_payment_method(
        :credit_card => {
          :number => "4111111111111111",
          :expiration_month => "11",
          :expiration_year => "2099"
        }
      )

      response.code.should == "422"
    end

    it "can pass merchant_account_id" do
      merchant_account_id = SpecHelper::NonDefaultMerchantAccountId

      raw_client_token = Braintree::ClientToken.generate(
        :merchant_account_id => merchant_account_id
      )
      client_token = decode_client_token(raw_client_token)

      client_token["merchantAccountId"].should == merchant_account_id
    end

    context "paypal" do
      it "includes the paypal options for a paypal merchant" do
        with_altpay_merchant do
          raw_client_token = Braintree::ClientToken.generate
          client_token = decode_client_token(raw_client_token)

          client_token["paypal"]["displayName"].should == "merchant who has paypal and sepa enabled"
          client_token["paypal"]["clientId"].should match(/.+/)
          client_token["paypal"]["privacyUrl"].should match("http://www.example.com/privacy_policy")
          client_token["paypal"]["userAgreementUrl"].should match("http://www.example.com/user_agreement")
          client_token["paypal"]["baseUrl"].should_not be_nil
        end
      end
    end
  end
end
