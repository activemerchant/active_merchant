require File.expand_path(File.dirname(__FILE__) + "/../../spec_helper")

describe Braintree::MerchantGateway do
  describe "create" do
    it "creates a merchant" do
      gateway = Braintree::Gateway.new(
        :client_id => "client_id$#{Braintree::Configuration.environment}$integration_client_id",
        :client_secret => "client_secret$#{Braintree::Configuration.environment}$integration_client_secret",
        :logger => Logger.new("/dev/null")
      )

      result = gateway.merchant.create(
        :email => "name@email.com",
        :country_code_alpha3 => "USA",
        :payment_methods => ["credit_card", "paypal"]
      )

      result.should be_success

      merchant = result.merchant
      merchant.id.should_not be_nil
      merchant.email.should == "name@email.com"
      merchant.company_name.should == "name@email.com"
      merchant.country_code_alpha3.should == "USA"
      merchant.country_code_alpha2.should == "US"
      merchant.country_code_numeric.should == "840"
      merchant.country_name.should == "United States of America"

      credentials = result.credentials
      credentials.access_token.should_not be_nil
      credentials.refresh_token.should_not be_nil
      credentials.expires_at.should_not be_nil
      credentials.token_type.should == "bearer"
    end

    it "gives an error when using invalid payment_methods" do
      gateway = Braintree::Gateway.new(
        :client_id => "client_id$#{Braintree::Configuration.environment}$integration_client_id",
        :client_secret => "client_secret$#{Braintree::Configuration.environment}$integration_client_secret",
        :logger => Logger.new("/dev/null")
      )

      result = gateway.merchant.create(
        :email => "name@email.com",
        :country_code_alpha3 => "USA",
        :payment_methods => ["fake_money"]
      )

      result.should_not be_success
      errors = result.errors.for(:merchant).on(:payment_methods)

      errors[0].code.should == Braintree::ErrorCodes::Merchant::PaymentMethodsAreInvalid
    end

    context "credentials" do
      around(:each) do |example|
        old_merchant_id_value = Braintree::Configuration.merchant_id
        example.run
        Braintree::Configuration.merchant_id = old_merchant_id_value
      end

      it "allows using a merchant_id passed in through Gateway" do
        Braintree::Configuration.merchant_id = nil

        gateway = Braintree::Gateway.new(
          :client_id => "client_id$#{Braintree::Configuration.environment}$integration_client_id",
          :client_secret => "client_secret$#{Braintree::Configuration.environment}$integration_client_secret",
          :merchant_id => "integration_merchant_id",
          :logger => Logger.new("/dev/null"),
        )
        result = gateway.merchant.create(
          :email => "name@email.com",
          :country_code_alpha3 => "USA",
          :payment_methods => ["credit_card", "paypal"]
        )

        result.should be_success
      end
    end

    context "multiple currencies" do
      before(:each) do
        @gateway = Braintree::Gateway.new(
          :client_id => "client_id$development$signup_client_id",
          :client_secret => "client_secret$development$signup_client_secret",
          :logger => Logger.new("/dev/null")
        )
      end

      it "creates a US multi currency merchant for paypal and credit_card" do
        result = @gateway.merchant.create(
          :email => "name@email.com",
          :country_code_alpha3 => "USA",
          :payment_methods => ["credit_card", "paypal"],
          :currencies => ["GBP", "USD"]
        )

        merchant = result.merchant
        merchant.id.should_not be_nil
        merchant.email.should == "name@email.com"
        merchant.company_name.should == "name@email.com"
        merchant.country_code_alpha3.should == "USA"
        merchant.country_code_alpha2.should == "US"
        merchant.country_code_numeric.should == "840"
        merchant.country_name.should == "United States of America"

        credentials = result.credentials
        credentials.access_token.should_not be_nil
        credentials.refresh_token.should_not be_nil
        credentials.expires_at.should_not be_nil
        credentials.token_type.should == "bearer"

        merchant_accounts = merchant.merchant_accounts
        merchant_accounts.count.should == 2

        merchant_account = merchant_accounts.detect { |ma| ma.id == "USD" }
        merchant_account.default.should == true
        merchant_account.currency_iso_code.should == "USD"

        merchant_account = merchant_accounts.detect { |ma| ma.id == "GBP" }
        merchant_account.default.should == false
        merchant_account.currency_iso_code.should == "GBP"
      end

      it "creates an EU multi currency merchant for paypal and credit_card" do
        result = @gateway.merchant.create(
          :email => "name@email.com",
          :country_code_alpha3 => "GBR",
          :payment_methods => ["credit_card", "paypal"],
          :currencies => ["GBP", "USD"]
        )

        merchant = result.merchant
        merchant.id.should_not be_nil
        merchant.email.should == "name@email.com"
        merchant.company_name.should == "name@email.com"
        merchant.country_code_alpha3.should == "GBR"
        merchant.country_code_alpha2.should == "GB"
        merchant.country_code_numeric.should == "826"
        merchant.country_name.should == "United Kingdom"

        credentials = result.credentials
        credentials.access_token.should_not be_nil
        credentials.refresh_token.should_not be_nil
        credentials.expires_at.should_not be_nil
        credentials.token_type.should == "bearer"

        merchant_accounts = merchant.merchant_accounts
        merchant_accounts.count.should == 2

        merchant_account = merchant_accounts.detect { |ma| ma.id == "GBP" }
        merchant_account.default.should == true
        merchant_account.currency_iso_code.should == "GBP"

        merchant_account = merchant_accounts.detect { |ma| ma.id == "USD" }
        merchant_account.default.should == false
        merchant_account.currency_iso_code.should == "USD"
      end


      it "creates a paypal-only merchant that accepts multiple currencies" do
        result = @gateway.merchant.create(
          :email => "name@email.com",
          :country_code_alpha3 => "USA",
          :payment_methods => ["paypal"],
          :currencies => ["GBP", "USD"],
          :paypal_account => {
            :client_id => "paypal_client_id",
            :client_secret => "paypal_client_secret",
          }
        )

        result.should be_success

        merchant = result.merchant
        merchant.id.should_not be_nil
        merchant.email.should == "name@email.com"
        merchant.company_name.should == "name@email.com"
        merchant.country_code_alpha3.should == "USA"
        merchant.country_code_alpha2.should == "US"
        merchant.country_code_numeric.should == "840"
        merchant.country_name.should == "United States of America"

        credentials = result.credentials
        credentials.access_token.should_not be_nil
        credentials.refresh_token.should_not be_nil
        credentials.expires_at.should_not be_nil
        credentials.token_type.should == "bearer"

        merchant_accounts = merchant.merchant_accounts
        merchant_accounts.count.should == 2

        merchant_account = merchant_accounts.detect { |ma| ma.id == "USD" }
        merchant_account.default.should == true
        merchant_account.currency_iso_code.should == "USD"

        merchant_account = merchant_accounts.detect { |ma| ma.id == "GBP" }
        merchant_account.default.should == false
        merchant_account.currency_iso_code.should == "GBP"
      end

      it "allows creation of non-US merchant if onboarding application is internal" do
        result = @gateway.merchant.create(
          :email => "name@email.com",
          :country_code_alpha3 => "JPN",
          :payment_methods => ["paypal"],
          :paypal_account => {
            :client_id => "paypal_client_id",
            :client_secret => "paypal_client_secret",
          }
        )

        result.should be_success

        merchant = result.merchant
        merchant.id.should_not be_nil
        merchant.email.should == "name@email.com"
        merchant.company_name.should == "name@email.com"
        merchant.country_code_alpha3.should == "JPN"
        merchant.country_code_alpha2.should == "JP"
        merchant.country_code_numeric.should == "392"
        merchant.country_name.should == "Japan"

        credentials = result.credentials
        credentials.access_token.should_not be_nil
        credentials.refresh_token.should_not be_nil
        credentials.expires_at.should_not be_nil
        credentials.token_type.should == "bearer"

        merchant_accounts = merchant.merchant_accounts
        merchant_accounts.count.should == 1

        merchant_account = merchant_accounts.detect { |ma| ma.id == "JPY" }
        merchant_account.default.should == true
        merchant_account.currency_iso_code.should == "JPY"
      end

      it "defaults to USD for non-US merchant if onboarding application is internal and country currency not supported" do
        result = @gateway.merchant.create(
          :email => "name@email.com",
          :country_code_alpha3 => "YEM",
          :payment_methods => ["paypal"],
          :paypal_account => {
            :client_id => "paypal_client_id",
            :client_secret => "paypal_client_secret",
          }
        )

        result.should be_success

        merchant = result.merchant
        merchant.id.should_not be_nil
        merchant.email.should == "name@email.com"
        merchant.company_name.should == "name@email.com"
        merchant.country_code_alpha3.should == "YEM"
        merchant.country_code_alpha2.should == "YE"
        merchant.country_code_numeric.should == "887"
        merchant.country_name.should == "Yemen"

        credentials = result.credentials
        credentials.access_token.should_not be_nil
        credentials.refresh_token.should_not be_nil
        credentials.expires_at.should_not be_nil
        credentials.token_type.should == "bearer"

        merchant_accounts = merchant.merchant_accounts
        merchant_accounts.count.should == 1

        merchant_account = merchant_accounts.detect { |ma| ma.id == "USD" }
        merchant_account.default.should == true
        merchant_account.currency_iso_code.should == "USD"
      end

      it "returns error if invalid currency is passed" do
        result = @gateway.merchant.create(
          :email => "name@email.com",
          :country_code_alpha3 => "USA",
          :payment_methods => ["paypal"],
          :currencies => ["FAKE", "GBP"],
          :paypal_account => {
            :client_id => "paypal_client_id",
            :client_secret => "paypal_client_secret",
          }
        )

        result.should_not be_success
        errors = result.errors.for(:merchant).on(:currencies)

        errors[0].code.should == Braintree::ErrorCodes::Merchant::CurrenciesAreInvalid
      end
    end
  end

  describe "provision_raw_apple_pay" do
    before { _save_config }
    after { _restore_config }

    context "merchant has processor connection supporting apple pay" do
      before do
        Braintree::Configuration.merchant_id = "integration_merchant_id"
        Braintree::Configuration.public_key = "integration_public_key"
        Braintree::Configuration.private_key = "integration_private_key"
      end

      it "succeeds" do
        result = Braintree::Merchant.provision_raw_apple_pay
        result.should be_success
        result.supported_networks.should == ["visa", "mastercard", "amex", "discover", "maestro"]
      end

      it "is repeatable" do
        result = Braintree::Merchant.provision_raw_apple_pay
        result.should be_success
        result = Braintree::Merchant.provision_raw_apple_pay
        result.should be_success
        result.supported_networks.should == ["visa", "mastercard", "amex", "discover", "maestro"]
      end
    end

    context "merchant has no processor connection supporting apple pay" do
      before do
        Braintree::Configuration.merchant_id = "forward_payment_method_merchant_id"
        Braintree::Configuration.public_key = "forward_payment_method_public_key"
        Braintree::Configuration.private_key = "forward_payment_method_private_key"
      end

      it "returns a validation error" do
        result = Braintree::Merchant.provision_raw_apple_pay
        result.should_not be_success
        result.errors.for(:apple_pay).first.code.should == Braintree::ErrorCodes::ApplePay::ApplePayCardsAreNotAccepted
      end
    end

    def _save_config
      @original_config = {
        :merchant_id => Braintree::Configuration.merchant_id,
        :public_key => Braintree::Configuration.public_key,
        :private_key => Braintree::Configuration.private_key,
      }
    end

    def _restore_config
      Braintree::Configuration.merchant_id = @original_config[:merchant_id]
      Braintree::Configuration.public_key = @original_config[:public_key]
      Braintree::Configuration.private_key = @original_config[:private_key]
    end
  end
end
