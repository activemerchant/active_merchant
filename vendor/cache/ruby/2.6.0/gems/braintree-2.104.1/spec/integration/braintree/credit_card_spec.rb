require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require File.expand_path(File.dirname(__FILE__) + "/client_api/spec_helper")

describe Braintree::CreditCard do
  describe "self.create" do
    it "throws and ArgumentError if given exipiration_date and any combination of expiration_month and expiration_year" do
      expect do
        Braintree::CreditCard.create :expiration_date => "anything", :expiration_month => "anything"
      end.to raise_error(ArgumentError, "create with both expiration_month and expiration_year or only expiration_date")
    end

    it "adds credit card to an existing customer" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2009",
        :cvv => "100",
      )
      result.success?.should == true
      credit_card = result.credit_card
      credit_card.token.should =~ /\A\w{4,}\z/
      credit_card.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      credit_card.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      credit_card.expiration_date.should == "05/2009"
      credit_card.unique_number_identifier.should =~ /\A\w{32}\z/
      credit_card.venmo_sdk?.should == false
      credit_card.image_url.should_not be_nil
    end

    it "supports creation of cards with security params" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2009",
        :cvv => "100",
        :device_session_id => "abc123",
        :fraud_merchant_id => "7"
      )
      result.success?.should == true
    end

    it "can provide expiration month and year separately" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_month => "05",
        :expiration_year => "2012"
      )
      result.success?.should == true
      credit_card = result.credit_card
      credit_card.expiration_month.should == "05"
      credit_card.expiration_year.should == "2012"
      credit_card.expiration_date.should == "05/2012"
    end

    it "can specify the desired token" do
      token = "token_#{rand(10**10)}"
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2009",
        :cvv => "100",
        :token => token
      )
      result.success?.should == true
      credit_card = result.credit_card
      credit_card.token.should == token
      credit_card.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      credit_card.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      credit_card.expiration_date.should == "05/2009"
    end

    it "accepts billing_address_id" do
      customer = Braintree::Customer.create!
      address = Braintree::Address.create!(:customer_id => customer.id, :first_name => "Bobby", :last_name => "Tables")

      credit_card = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
        :expiration_date => "05/2009",
        :billing_address_id => address.id
      ).credit_card

      credit_card.billing_address.id.should == address.id
      credit_card.billing_address.first_name.should == "Bobby"
      credit_card.billing_address.last_name.should == "Tables"
    end

    it "accepts empty options hash" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
        :expiration_date => "05/2009",
        :options => {}
      )
      result.success?.should == true
    end

    it "verifies the credit card if options[verify_card]=true" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
        :expiration_date => "05/2009",
        :options => {:verify_card => true}
      )
      result.success?.should == false
      result.credit_card_verification.status.should == Braintree::Transaction::Status::ProcessorDeclined
      result.credit_card_verification.processor_response_code.should == "2000"
      result.credit_card_verification.processor_response_text.should == "Do Not Honor"
      result.credit_card_verification.cvv_response_code.should == "I"
      result.credit_card_verification.avs_error_response_code.should == nil
      result.credit_card_verification.avs_postal_code_response_code.should == "I"
      result.credit_card_verification.avs_street_address_response_code.should == "I"
    end

    it "allows passing a specific verification amount" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
        :expiration_date => "05/2009",
        :options => {:verify_card => true, :verification_amount => "100.00"}
      )
      result.success?.should == false
      result.credit_card_verification.status.should == Braintree::Transaction::Status::ProcessorDeclined
      result.credit_card_verification.processor_response_code.should == "2000"
      result.credit_card_verification.processor_response_text.should == "Do Not Honor"
      result.credit_card_verification.cvv_response_code.should == "I"
      result.credit_card_verification.avs_error_response_code.should == nil
      result.credit_card_verification.avs_postal_code_response_code.should == "I"
      result.credit_card_verification.avs_street_address_response_code.should == "I"
    end

    it "returns risk data on verification on credit_card create" do
      with_advanced_fraud_integration_merchant do
        customer = Braintree::Customer.create!
        credit_card = Braintree::CreditCard.create!(
          :cardholder_name => "Original Holder",
          :customer_id => customer.id,
          :cvv => "123",
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2020",
          :options => {:verify_card => true}
        )
        verification = credit_card.verification
        verification.risk_data.should respond_to(:id)
        verification.risk_data.should respond_to(:decision)
        verification.risk_data.should respond_to(:device_data_captured)
        verification.risk_data.should respond_to(:fraud_service_provider)
      end
    end

    it "exposes the gateway rejection reason on verification" do
      old_merchant = Braintree::Configuration.merchant_id
      old_public_key = Braintree::Configuration.public_key
      old_private_key = Braintree::Configuration.private_key

      begin
        Braintree::Configuration.merchant_id = "processing_rules_merchant_id"
        Braintree::Configuration.public_key = "processing_rules_public_key"
        Braintree::Configuration.private_key = "processing_rules_private_key"

        customer = Braintree::Customer.create!
        result = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009",
          :cvv => "200",
          :options => {:verify_card => true}
        )
        result.success?.should == false
        result.credit_card_verification.gateway_rejection_reason.should == Braintree::Transaction::GatewayRejectionReason::CVV
      ensure
        Braintree::Configuration.merchant_id = old_merchant
        Braintree::Configuration.public_key = old_public_key
        Braintree::Configuration.private_key = old_private_key
      end
    end

    it "verifies the credit card if options[verify_card]=true" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
        :expiration_date => "05/2009",
        :options => {:verify_card => true, :verification_amount => "1.01"}
      )
      result.success?.should == false
      result.credit_card_verification.status.should == Braintree::Transaction::Status::ProcessorDeclined
      result.credit_card_verification.processor_response_code.should == "2000"
      result.credit_card_verification.processor_response_text.should == "Do Not Honor"
      result.credit_card_verification.cvv_response_code.should == "I"
      result.credit_card_verification.avs_error_response_code.should == nil
      result.credit_card_verification.avs_postal_code_response_code.should == "I"
      result.credit_card_verification.avs_street_address_response_code.should == "I"
    end

    it "allows user to specify merchant account for verification" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
        :expiration_date => "05/2009",
        :options => {
          :verify_card => true,
          :verification_merchant_account_id => SpecHelper::NonDefaultMerchantAccountId
        }
      )
      result.success?.should == false
      result.credit_card_verification.merchant_account_id.should == SpecHelper::NonDefaultMerchantAccountId
    end

    it "does not verify the card if options[verify_card]=false" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
        :expiration_date => "05/2009",
        :options => {:verify_card => false}
      )
      result.success?.should == true
    end

    it "validates presence of three_d_secure_version in 3ds pass thru params" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :payment_method_nonce => Braintree::Test::Nonce::Transactable,
        :three_d_secure_pass_thru => {
          :eci_flag => '02',
          :cavv => 'some_cavv',
          :xid => 'some_xid',
          :authentication_response => 'Y',
          :directory_response => 'Y',
          :cavv_algorithm => '2',
          :ds_transaction_id => 'some_ds_transaction_id',
        },
        :options => {:verify_card => true}
      )
      expect(result).not_to be_success
      error = result.errors.for(:verification).first
      expect(error.code).to eq(Braintree::ErrorCodes::Verification::ThreeDSecurePassThru::ThreeDSecureVersionIsRequired)
      expect(error.message).to eq("ThreeDSecureVersion is required.")
    end

    it "accepts three_d_secure pass thru params in the request" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :payment_method_nonce => Braintree::Test::Nonce::Transactable,
        :three_d_secure_pass_thru => {
          :eci_flag => '02',
          :cavv => 'some_cavv',
          :xid => 'some_xid',
          :three_d_secure_version => '1.0.2',
          :authentication_response => 'Y',
          :directory_response => 'Y',
          :cavv_algorithm => '2',
          :ds_transaction_id => 'some_ds_transaction_id',
        },
        :options => {:verify_card => true}
      )
      result.success?.should == true

    end

    it "returns 3DS info on cc verification" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :payment_method_nonce => Braintree::Test::Nonce::ThreeDSecureVisaFullAuthentication,
        :options => {:verify_card => true}
      )
      result.success?.should == true

      three_d_secure_info = result.credit_card.verification.three_d_secure_info
      three_d_secure_info.enrolled.should == "Y"
      three_d_secure_info.should be_liability_shifted
      three_d_secure_info.should be_liability_shift_possible
      three_d_secure_info.status.should == "authenticate_successful"
      three_d_secure_info.cavv.should == "cavv_value"
      three_d_secure_info.xid.should == "xid_value"
      three_d_secure_info.eci_flag.should == "05"
      three_d_secure_info.three_d_secure_version.should == "1.0.2"
      three_d_secure_info.ds_transaction_id.should == nil
      three_d_secure_info.three_d_secure_authentication_id.should_not be_nil
    end

    it "adds credit card with billing address to customer" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::MasterCard,
        :expiration_date => "12/2009",
        :billing_address => {
          :street_address => "123 Abc Way",
          :locality => "Chicago",
          :region => "Illinois",
          :postal_code => "60622"
        }
      )
      result.success?.should == true
      credit_card = result.credit_card
      credit_card.bin.should == Braintree::Test::CreditCardNumbers::MasterCard[0, 6]
      credit_card.billing_address.street_address.should == "123 Abc Way"
    end

    it "adds credit card with billing using country_code" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::MasterCard,
        :expiration_date => "12/2009",
        :billing_address => {
          :country_name => "United States of America",
          :country_code_alpha2 => "US",
          :country_code_alpha3 => "USA",
          :country_code_numeric => "840"
        }
      )
      result.success?.should == true
      credit_card = result.credit_card
      credit_card.billing_address.country_name.should == "United States of America"
      credit_card.billing_address.country_code_alpha2.should == "US"
      credit_card.billing_address.country_code_alpha3.should == "USA"
      credit_card.billing_address.country_code_numeric.should == "840"
    end

    it "returns an error when given inconsistent country information" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::MasterCard,
        :expiration_date => "12/2009",
        :billing_address => {
          :country_name => "Mexico",
          :country_code_alpha2 => "US"
        }
      )
      result.success?.should == false
      result.errors.for(:credit_card).for(:billing_address).on(:base).map { |e| e.code }.should include(Braintree::ErrorCodes::Address::InconsistentCountry)
    end

    it "returns an error response if unsuccessful" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "invalid_date"
      )
      result.success?.should == false
      result.errors.for(:credit_card).on(:expiration_date)[0].message.should == "Expiration date is invalid."
    end

    it "can set the default flag" do
      customer = Braintree::Customer.create!
      card1 = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2009"
      ).credit_card
      card1.should be_default

      card2 = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2009",
        :options => {
          :make_default => true
        }
      ).credit_card
      card2.should be_default

      Braintree::CreditCard.find(card1.token).should_not be_default
    end

    it "can set the network transaction identifier when creating a credit card" do
      customer = Braintree::Customer.create!

      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2009",
        :external_vault => {
          :network_transaction_id => "MCC123456789",
        },
      )

      expect(result.success?).to eq(true)
    end

    context "card type indicators" do
      it "sets the prepaid field if the card is prepaid" do
        customer = Braintree::Customer.create!
        result = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::CardTypeIndicators::Prepaid,
          :expiration_date => "05/2014",
          :options => {:verify_card => true}
        )
        credit_card = result.credit_card
        credit_card.prepaid.should == Braintree::CreditCard::Prepaid::Yes
      end

      it "sets the healthcare field if the card is healthcare" do
        customer = Braintree::Customer.create!
        result = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::CardTypeIndicators::Healthcare,
          :expiration_date => "05/2014",
          :options => {:verify_card => true}
        )
        credit_card = result.credit_card
        credit_card.healthcare.should == Braintree::CreditCard::Healthcare::Yes
        credit_card.product_id.should == "J3"
      end

      it "sets the durbin regulated field if the card is durbin regulated" do
        customer = Braintree::Customer.create!
        result = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::CardTypeIndicators::DurbinRegulated,
          :expiration_date => "05/2014",
          :options => {:verify_card => true}
        )
        credit_card = result.credit_card
        credit_card.durbin_regulated.should == Braintree::CreditCard::DurbinRegulated::Yes
      end

      it "sets the country of issuance field" do
        customer = Braintree::Customer.create!
        result = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::CardTypeIndicators::CountryOfIssuance,
          :expiration_date => "05/2014",
          :options => {:verify_card => true}
        )
        credit_card = result.credit_card
        credit_card.country_of_issuance.should == Braintree::Test::CreditCardDefaults::CountryOfIssuance
      end

      it "sets the issuing bank field" do
        customer = Braintree::Customer.create!
        result = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::CardTypeIndicators::IssuingBank,
          :expiration_date => "05/2014",
          :options => {:verify_card => true}
        )
        credit_card = result.credit_card
        credit_card.issuing_bank.should == Braintree::Test::CreditCardDefaults::IssuingBank
      end

      it "sets the payroll field if the card is payroll" do
        customer = Braintree::Customer.create!
        result = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::CardTypeIndicators::Payroll,
          :expiration_date => "05/2014",
          :options => {:verify_card => true}
        )
        credit_card = result.credit_card
        credit_card.payroll.should == Braintree::CreditCard::Payroll::Yes
        credit_card.product_id.should == "MSA"
      end

      it "sets the debit field if the card is debit" do
        customer = Braintree::Customer.create!
        result = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::CardTypeIndicators::Debit,
          :expiration_date => "05/2014",
          :options => {:verify_card => true}
        )
        credit_card = result.credit_card
        credit_card.debit.should == Braintree::CreditCard::Debit::Yes
      end

      it "sets the commercial field if the card is commercial" do
        customer = Braintree::Customer.create!
        result = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::CardTypeIndicators::Commercial,
          :expiration_date => "05/2014",
          :options => {:verify_card => true}
        )
        credit_card = result.credit_card
        credit_card.commercial.should == Braintree::CreditCard::Commercial::Yes
      end

      it "sets negative card type identifiers" do
        customer = Braintree::Customer.create!
        result = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::CardTypeIndicators::No,
          :expiration_date => "05/2014",
          :options => {:verify_card => true}
        )
        credit_card = result.credit_card
        credit_card.prepaid.should == Braintree::CreditCard::Prepaid::No
        credit_card.commercial.should == Braintree::CreditCard::Prepaid::No
        credit_card.payroll.should == Braintree::CreditCard::Prepaid::No
        credit_card.debit.should == Braintree::CreditCard::Prepaid::No
        credit_card.durbin_regulated.should == Braintree::CreditCard::Prepaid::No
        credit_card.healthcare.should == Braintree::CreditCard::Prepaid::No
        credit_card.product_id.should == "MSB"
      end

      it "doesn't set the card type identifiers for an un-identified card" do
        customer = Braintree::Customer.create!
        result = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::CardTypeIndicators::Unknown,
          :expiration_date => "05/2014",
          :options => {:verify_card => true}
        )
        credit_card = result.credit_card
        credit_card.prepaid.should == Braintree::CreditCard::Prepaid::Unknown
        credit_card.commercial.should == Braintree::CreditCard::Prepaid::Unknown
        credit_card.payroll.should == Braintree::CreditCard::Prepaid::Unknown
        credit_card.debit.should == Braintree::CreditCard::Prepaid::Unknown
        credit_card.durbin_regulated.should == Braintree::CreditCard::Prepaid::Unknown
        credit_card.healthcare.should == Braintree::CreditCard::Prepaid::Unknown
        credit_card.country_of_issuance == Braintree::CreditCard::CountryOfIssuance::Unknown
        credit_card.issuing_bank == Braintree::CreditCard::IssuingBank::Unknown
        credit_card.product_id == Braintree::CreditCard::ProductId::Unknown
      end
    end

    context "venmo_sdk" do
      describe "venmo_sdk_payment_method_code" do
        it "can pass a venmo sdk payment method code" do
          customer = Braintree::Customer.create!
          result = Braintree::CreditCard.create(
            :customer_id => customer.id,
            :venmo_sdk_payment_method_code => Braintree::Test::VenmoSDK::VisaPaymentMethodCode
          )
          result.success?.should == true
          result.credit_card.venmo_sdk?.should == false
          result.credit_card.bin.should == "400934"
          result.credit_card.last_4.should == "1881"
        end

        it "success? returns false when given an invalid venmo sdk payment method code" do
          customer = Braintree::Customer.create!
          result = Braintree::CreditCard.create(
            :customer_id => customer.id,
            :venmo_sdk_payment_method_code => Braintree::Test::VenmoSDK::InvalidPaymentMethodCode
          )

          result.success?.should == false
          result.message.should == "Invalid VenmoSDK payment method code"
          result.errors.first.code.should == "91727"
        end
      end

      describe "venmo_sdk_session" do
        it "venmo_sdk? returns true when given a valid session" do
          customer = Braintree::Customer.create!
          result = Braintree::CreditCard.create(
            :customer_id => customer.id,
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009",
            :cvv => "100",
            :options => {
              :venmo_sdk_session => Braintree::Test::VenmoSDK::Session
            }
          )
          result.success?.should == true
          result.credit_card.venmo_sdk?.should == false
        end

        it "venmo_sdk? returns false when given an invalid session" do
          customer = Braintree::Customer.create!
          result = Braintree::CreditCard.create(
            :customer_id => customer.id,
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009",
            :cvv => "100",
            :options => {
              :venmo_sdk_session => Braintree::Test::VenmoSDK::InvalidSession
            }
          )
          result.success?.should == true
          result.credit_card.venmo_sdk?.should == false
        end
      end
    end

    context "client API" do
      it "adds credit card to an existing customer using a payment method nonce" do
        nonce = nonce_for_new_payment_method(
          :credit_card => {
            :number => "4111111111111111",
            :expiration_month => "11",
            :expiration_year => "2099",
          },
          :share => true
        )
        customer = Braintree::Customer.create!
        result = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :payment_method_nonce => nonce
        )

        result.success?.should == true
        credit_card = result.credit_card
        credit_card.bin.should == "411111"
        credit_card.last_4.should == "1111"
        credit_card.expiration_date.should == "11/2099"
      end
    end

    context "card_type" do
      it "is set to Elo" do
        customer = Braintree::Customer.create!
        result = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::Elo,
          :expiration_date => "10/2020",
        )
        result.success?.should == true
        credit_card = result.credit_card
        credit_card.card_type.should == Braintree::CreditCard::CardType::Elo
      end
    end

    context "verification_account_type" do
      it "verifies card with account_type debit" do
        customer = Braintree::Customer.create!
        result = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::Hiper,
          :expiration_month => "11",
          :expiration_year => "2099",
          :options => {
            :verify_card => true,
            :verification_merchant_account_id => SpecHelper::HiperBRLMerchantAccountId,
            :verification_account_type => "debit",
          }
        )

        expect(result).to be_success
      end

      it "verifies card with account_type credit" do
        customer = Braintree::Customer.create!
        result = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::Hiper,
          :expiration_month => "11",
          :expiration_year => "2099",
          :options => {
            :verify_card => true,
            :verification_merchant_account_id => SpecHelper::HiperBRLMerchantAccountId,
            :verification_account_type => "credit",
          }
        )

        expect(result).to be_success
      end

      it "errors with invalid account_type" do
        customer = Braintree::Customer.create!
        result = Braintree::CreditCard.create(
          :number => Braintree::Test::CreditCardNumbers::Hiper,
          :expiration_month => "11",
          :expiration_year => "2099",
          :options => {
            :verify_card => true,
            :verification_merchant_account_id => SpecHelper::HiperBRLMerchantAccountId,
            :verification_account_type => "ach",
          }
        )

        expect(result).to_not be_success
        expect(result.errors.for(:credit_card).for(:options).on(:verification_account_type)[0].code).to eq Braintree::ErrorCodes::CreditCard::VerificationAccountTypeIsInvalid
      end

      it "errors when account_type not supported by merchant" do
        customer = Braintree::Customer.create!
        result = Braintree::CreditCard.create(
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_month => "11",
          :expiration_year => "2099",
          :options => {
            :verify_card => true,
            :verification_account_type => "credit",
          }
        )

        expect(result).to_not be_success
        expect(result.errors.for(:credit_card).for(:options).on(:verification_account_type)[0].code).to eq Braintree::ErrorCodes::CreditCard::VerificationAccountTypeNotSupported
      end
    end
  end

  describe "self.create!" do
    it "returns the credit card if successful" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :customer_id => customer.id,
        :cardholder_name => "Adam Davis",
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2009"
      )
      credit_card.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      credit_card.cardholder_name.should == "Adam Davis"
      credit_card.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      credit_card.expiration_date.should == "05/2009"
    end

    it "raises a ValidationsFailed if unsuccessful" do
      customer = Braintree::Customer.create!
      expect do
        Braintree::CreditCard.create!(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "invalid_date"
        )
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "self.credit" do
    it "creates a credit transaction using the payment method token, returning a result object" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )
      result = Braintree::CreditCard.credit(
        customer.credit_cards[0].token,
        :amount => "100.00"
      )
      result.success?.should == true
      result.transaction.amount.should == BigDecimal("100.00")
      result.transaction.type.should == "credit"
      result.transaction.customer_details.id.should == customer.id
      result.transaction.credit_card_details.token.should == customer.credit_cards[0].token
      result.transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      result.transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      result.transaction.credit_card_details.expiration_date.should == "05/2010"
    end
  end

  describe "self.credit!" do
    it "creates a credit transaction using the payment method token, returning the transaction" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )
      transaction = Braintree::CreditCard.credit!(
        customer.credit_cards[0].token,
        :amount => "100.00"
      )
      transaction.amount.should == BigDecimal("100.00")
      transaction.type.should == "credit"
      transaction.customer_details.id.should == customer.id
      transaction.credit_card_details.token.should == customer.credit_cards[0].token
      transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      transaction.credit_card_details.expiration_date.should == "05/2010"
    end
  end

  describe "self.create_from_transparent_redirect" do
    it "returns a successful result if successful" do
      result = Braintree::Customer.create
      result.success?.should == true
      customer = result.customer
      params =  {
        :credit_card => {
          :cardholder_name => "Card Holder",
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2012"
        }
      }
      tr_data_params = {
        :credit_card => {
          :customer_id => customer.id
        }
      }
      tr_data = Braintree::TransparentRedirect.create_credit_card_data({:redirect_url => "http://example.com"}.merge(tr_data_params))
      query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params, Braintree::CreditCard.create_credit_card_url)
      result = Braintree::CreditCard.create_from_transparent_redirect(query_string_response)
      result.success?.should == true
      credit_card = result.credit_card
      credit_card.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      credit_card.cardholder_name.should == "Card Holder"
      credit_card.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      credit_card.expiration_month.should == "05"
      credit_card.expiration_year.should == "2012"
      credit_card.expiration_date.should == "05/2012"
      credit_card.customer_id.should == customer.id
    end

    it "create card as default" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :cardholder_name => "Old Cardholder Name",
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2012"
        }
      )
      card1 = customer.credit_cards[0]

      params =  {
        :credit_card => {
          :cardholder_name => "Card Holder",
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2012",
          :options => {:make_default => true}
        }
      }
      tr_data_params = {
        :credit_card => {
          :customer_id => customer.id
        }
      }
      tr_data = Braintree::TransparentRedirect.create_credit_card_data({:redirect_url => "http://example.com"}.merge(tr_data_params))
      query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params, Braintree::CreditCard.create_credit_card_url)
      result = Braintree::CreditCard.create_from_transparent_redirect(query_string_response)
      result.success?.should == true
      card2 = result.credit_card

      Braintree::CreditCard.find(card1.token).should_not be_default
      card2.should be_default
    end

    it "returns xml with nested errors if validation errors" do
      customer = Braintree::Customer.create.customer
      params =  {
        :credit_card => {
          :cardholder_name => "Card Holder",
          :number => "eleventy",
          :expiration_date => "y2k"
        }
      }
      tr_data_params = {
        :credit_card => {
          :customer_id => customer.id
        }
      }
      tr_data = Braintree::TransparentRedirect.create_credit_card_data({:redirect_url => "http://example.com"}.merge(tr_data_params))
      query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params, Braintree::CreditCard.create_credit_card_url)
      result = Braintree::CreditCard.create_from_transparent_redirect(query_string_response)
      result.success?.should == false
      result.params[:customer_id] == customer.id
      result.params[:credit_card]["cardholder_name"] == customer.id
      result.params[:credit_card]["number"] == "eleventy"
      result.params[:credit_card]["exipiration_date"] == "y2k"
    end
  end

  describe "self.update" do
    it "updates the credit card" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :cardholder_name => "Original Holder",
        :customer_id => customer.id,
        :cvv => "123",
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      )
      update_result = Braintree::CreditCard.update(credit_card.token,
        :cardholder_name => "New Holder",
        :cvv => "456",
        :number => Braintree::Test::CreditCardNumbers::MasterCard,
        :expiration_date => "06/2013"
      )
      update_result.success?.should == true
      update_result.credit_card.should == credit_card
      updated_credit_card = update_result.credit_card
      updated_credit_card.bin.should == Braintree::Test::CreditCardNumbers::MasterCard[0, 6]
      updated_credit_card.last_4.should == Braintree::Test::CreditCardNumbers::MasterCard[-4..-1]
      updated_credit_card.expiration_date.should == "06/2013"
      updated_credit_card.cardholder_name.should == "New Holder"
    end

    it "validates presence of three_d_secure_version in 3ds pass thru params" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :cardholder_name => "Original Holder",
        :customer_id => customer.id,
        :cvv => "123",
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      )
      result = Braintree::CreditCard.update(credit_card.token,
        :payment_method_nonce => Braintree::Test::Nonce::Transactable,
        :three_d_secure_pass_thru => {
          :eci_flag => '02',
          :cavv => 'some_cavv',
          :xid => 'some_xid',
          :authentication_response => 'Y',
          :directory_response => 'Y',
          :cavv_algorithm => '2',
          :ds_transaction_id => 'some_ds_transaction_id',
        },
        :options => {:verify_card => true}
      )
      expect(result).not_to be_success
      error = result.errors.for(:verification).first
      expect(error.code).to eq(Braintree::ErrorCodes::Verification::ThreeDSecurePassThru::ThreeDSecureVersionIsRequired)
      expect(error.message).to eq("ThreeDSecureVersion is required.")
    end

    it "accepts three_d_secure pass thru params in the request" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :cardholder_name => "Original Holder",
        :customer_id => customer.id,
        :cvv => "123",
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      )
      result = Braintree::CreditCard.update(credit_card.token,
        :payment_method_nonce => Braintree::Test::Nonce::Transactable,
        :three_d_secure_pass_thru => {
          :eci_flag => '02',
          :cavv => 'some_cavv',
          :three_d_secure_version=> "2.1.0",
          :xid => 'some_xid',
          :authentication_response => 'Y',
          :directory_response => 'Y',
          :cavv_algorithm => '2',
          :ds_transaction_id => 'some_ds_transaction_id',
        },
        :options => {:verify_card => true}
      )

      result.success?.should == true

    end

    context "billing address" do
      it "creates a new billing address by default" do
        customer = Braintree::Customer.create!
        credit_card = Braintree::CreditCard.create!(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2012",
          :billing_address => {
            :street_address => "123 Nigeria Ave"
          }
        )
        update_result = Braintree::CreditCard.update(credit_card.token,
          :billing_address => {
            :region => "IL"
          }
        )
        update_result.success?.should == true
        updated_credit_card = update_result.credit_card
        updated_credit_card.billing_address.region.should == "IL"
        updated_credit_card.billing_address.street_address.should == nil
        updated_credit_card.billing_address.id.should_not == credit_card.billing_address.id
      end

      it "updates the billing address if option is specified" do
        customer = Braintree::Customer.create!
        credit_card = Braintree::CreditCard.create!(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2012",
          :billing_address => {
            :street_address => "123 Nigeria Ave"
          }
        )
        update_result = Braintree::CreditCard.update(credit_card.token,
          :billing_address => {
            :region => "IL",
            :options => {:update_existing => true}
          }
        )
        update_result.success?.should == true
        updated_credit_card = update_result.credit_card
        updated_credit_card.billing_address.region.should == "IL"
        updated_credit_card.billing_address.street_address.should == "123 Nigeria Ave"
        updated_credit_card.billing_address.id.should == credit_card.billing_address.id
      end

      it "updates the country via codes" do
        customer = Braintree::Customer.create!
        credit_card = Braintree::CreditCard.create!(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2012",
          :billing_address => {
            :street_address => "123 Nigeria Ave"
          }
        )
        update_result = Braintree::CreditCard.update(credit_card.token,
          :billing_address => {
            :country_name => "American Samoa",
            :country_code_alpha2 => "AS",
            :country_code_alpha3 => "ASM",
            :country_code_numeric => "016",
            :options => {:update_existing => true}
          }
        )
        update_result.success?.should == true
        updated_credit_card = update_result.credit_card
        updated_credit_card.billing_address.country_name.should == "American Samoa"
        updated_credit_card.billing_address.country_code_alpha2.should == "AS"
        updated_credit_card.billing_address.country_code_alpha3.should == "ASM"
        updated_credit_card.billing_address.country_code_numeric.should == "016"
      end
    end

    it "can pass expiration_month and expiration_year" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      )
      update_result = Braintree::CreditCard.update(credit_card.token,
        :number => Braintree::Test::CreditCardNumbers::MasterCard,
        :expiration_month => "07",
        :expiration_year => "2011"
      )
      update_result.success?.should == true
      update_result.credit_card.should == credit_card
      update_result.credit_card.expiration_month.should == "07"
      update_result.credit_card.expiration_year.should == "2011"
      update_result.credit_card.expiration_date.should == "07/2011"
    end

    it "verifies the update if options[verify_card]=true" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :cardholder_name => "Original Holder",
        :customer_id => customer.id,
        :cvv => "123",
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      )
      update_result = Braintree::CreditCard.update(credit_card.token,
        :cardholder_name => "New Holder",
        :cvv => "456",
        :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::MasterCard,
        :expiration_date => "06/2013",
        :options => {:verify_card => true}
      )
      update_result.success?.should == false
      update_result.credit_card_verification.status.should == Braintree::Transaction::Status::ProcessorDeclined
      update_result.credit_card_verification.gateway_rejection_reason.should be_nil
    end

    it "can update the billing address" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :cardholder_name => "Original Holder",
        :customer_id => customer.id,
        :cvv => "123",
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012",
        :billing_address => {
          :first_name => "Old First Name",
          :last_name => "Old Last Name",
          :company => "Old Company",
          :street_address => "123 Old St",
          :extended_address => "Apt Old",
          :locality => "Old City",
          :region => "Old State",
          :postal_code => "12345",
          :country_name => "Canada"
        }
      )
      result = Braintree::CreditCard.update(credit_card.token,
        :options => {:verify_card => false},
        :billing_address => {
          :first_name => "New First Name",
          :last_name => "New Last Name",
          :company => "New Company",
          :street_address => "123 New St",
          :extended_address => "Apt New",
          :locality => "New City",
          :region => "New State",
          :postal_code => "56789",
          :country_name => "United States of America"
        }
      )
      result.success?.should == true
      address = result.credit_card.billing_address
      address.first_name.should == "New First Name"
      address.last_name.should == "New Last Name"
      address.company.should == "New Company"
      address.street_address.should == "123 New St"
      address.extended_address.should == "Apt New"
      address.locality.should == "New City"
      address.region.should == "New State"
      address.postal_code.should == "56789"
      address.country_name.should == "United States of America"
    end

    it "returns an error response if invalid" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :cardholder_name => "Original Holder",
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      )
      update_result = Braintree::CreditCard.update(credit_card.token,
        :cardholder_name => "New Holder",
        :number => "invalid",
        :expiration_date => "05/2014"
      )
      update_result.success?.should == false
      update_result.errors.for(:credit_card).on(:number)[0].message.should == "Credit card number must be 12-19 digits."
    end

    it "can update the default" do
      customer = Braintree::Customer.create!
      card1 = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2009"
      ).credit_card
      card2 = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2009"
      ).credit_card

      card1.should be_default
      card2.should_not be_default

      Braintree::CreditCard.update(card2.token, :options => {:make_default => true})

      Braintree::CreditCard.find(card1.token).should_not be_default
      Braintree::CreditCard.find(card2.token).should be_default
    end

    context "verification_account_type" do
      it "updates the credit card with account_type credit" do
        customer = Braintree::Customer.create!
        card = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::Hiper,
          :expiration_date => "06/2013",
        ).credit_card
        update_result = Braintree::CreditCard.update(
          card.token,
          :options => {
            :verify_card => true,
            :verification_account_type => "credit",
            :verification_merchant_account_id => SpecHelper::HiperBRLMerchantAccountId,
          },
        )
        expect(update_result).to be_success
      end

      it "updates the credit card with account_type debit" do
        customer = Braintree::Customer.create!
        card = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::Hiper,
          :expiration_date => "06/2013",
        ).credit_card
        update_result = Braintree::CreditCard.update(
          card.token,
          :options => {
            :verify_card => true,
            :verification_account_type => "debit",
            :verification_merchant_account_id => SpecHelper::HiperBRLMerchantAccountId,
          },
        )
        expect(update_result).to be_success
      end
    end
  end

  describe "self.update!" do
    it "updates the credit card and returns true if valid" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :cardholder_name => "Original Holder",
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      )
      updated_credit_card = Braintree::CreditCard.update!(credit_card.token,
        :cardholder_name => "New Holder",
        :number => Braintree::Test::CreditCardNumbers::MasterCard,
        :expiration_date => "06/2013"
      )
      updated_credit_card.token.should == credit_card.token
      updated_credit_card.bin.should == Braintree::Test::CreditCardNumbers::MasterCard[0, 6]
      updated_credit_card.last_4.should == Braintree::Test::CreditCardNumbers::MasterCard[-4..-1]
      updated_credit_card.expiration_date.should == "06/2013"
      updated_credit_card.cardholder_name.should == "New Holder"
      updated_credit_card.updated_at.between?(Time.now - 60, Time.now).should == true
    end

    it "raises a ValidationsFailed if invalid" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :cardholder_name => "Original Holder",
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      )
      expect do
        Braintree::CreditCard.update!(credit_card.token,
          :cardholder_name => "New Holder",
          :number => Braintree::Test::CreditCardNumbers::MasterCard,
          :expiration_date => "invalid/date"
        )
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "self.update_from_transparent_redirect" do
    it "updates the credit card" do
      old_token = "token_#{rand(10**10)}"
      new_token = "token_#{rand(10**10)}"
      customer = Braintree::Customer.create!(
        :credit_card => {
          :cardholder_name => "Old Cardholder Name",
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2012",
          :token => old_token
        }
      )
      credit_card = customer.credit_cards[0]
      params = {
        :credit_card => {
          :cardholder_name => "New Cardholder Name",
          :number => Braintree::Test::CreditCardNumbers::MasterCard,
          :expiration_date => "05/2014"
        }
      }
      tr_data_params = {
        :payment_method_token => old_token,
        :credit_card => {
          :token => new_token
        }
      }
      tr_data = Braintree::TransparentRedirect.update_credit_card_data({:redirect_url => "http://example.com"}.merge(tr_data_params))
      query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params, Braintree::CreditCard.update_credit_card_url)
      result = Braintree::CreditCard.update_from_transparent_redirect(query_string_response)
      result.success?.should == true
      credit_card = result.credit_card
      credit_card.cardholder_name.should == "New Cardholder Name"
      credit_card.masked_number.should == "555555******4444"
      credit_card.expiration_date.should == "05/2014"
      credit_card.token.should == new_token
    end

    it "updates the default credit card" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :cardholder_name => "Old Cardholder Name",
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2012"
        }
      )
      card1 = customer.credit_cards[0]

      card2 = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2009"
      ).credit_card

      card1.should be_default
      card2.should_not be_default

      params = {
        :credit_card => {
          :options => {:make_default => true}
        }
      }
      tr_data_params = {
        :payment_method_token => card2.token
      }
      tr_data = Braintree::TransparentRedirect.update_credit_card_data({:redirect_url => "http://example.com"}.merge(tr_data_params))
      query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params, Braintree::CreditCard.update_credit_card_url)
      result = Braintree::CreditCard.update_from_transparent_redirect(query_string_response)

      Braintree::CreditCard.find(card1.token).should_not be_default
      Braintree::CreditCard.find(card2.token).should be_default
    end
  end

  describe "credit" do
    it "creates a credit transaction using the customer, returning a result object" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )
      result = customer.credit_cards[0].credit(
        :amount => "100.00"
      )
      result.success?.should == true
      result.transaction.amount.should == BigDecimal("100.00")
      result.transaction.type.should == "credit"
      result.transaction.customer_details.id.should == customer.id
      result.transaction.credit_card_details.token.should == customer.credit_cards[0].token
      result.transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      result.transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      result.transaction.credit_card_details.expiration_date.should == "05/2010"
    end
  end

  describe "credit!" do
    it "returns the created credit tranaction if valid" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )
      transaction = customer.credit_cards[0].credit!(:amount => "100.00")
      transaction.amount.should == BigDecimal("100.00")
      transaction.type.should == "credit"
      transaction.customer_details.id.should == customer.id
      transaction.credit_card_details.token.should == customer.credit_cards[0].token
      transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      transaction.credit_card_details.expiration_date.should == "05/2010"
    end

    it "raises a ValidationsFailed if invalid" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )
      expect do
        customer.credit_cards[0].credit!(:amount => "invalid")
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "self.delete" do
    it "deletes the credit card" do
      customer = Braintree::Customer.create.customer
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      )

      result.success?.should == true
      credit_card = result.credit_card
      Braintree::CreditCard.delete(credit_card.token).should == true
      expect do
        Braintree::CreditCard.find(credit_card.token)
      end.to raise_error(Braintree::NotFoundError)
    end
  end

  describe "self.expired" do
    it "can iterate over all items, and make sure they are all expired" do
      customer = Braintree::Customer.all.first

      (110 - Braintree::CreditCard.expired.maximum_size).times do
        Braintree::CreditCard.create!(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "01/#{Time.now.year - 3}"
        )
      end

      collection = Braintree::CreditCard.expired
      collection.maximum_size.should > 100

      credit_card_ids = collection.map do |c|
        c.expired?.should == true
        c.token
      end.uniq.compact
      credit_card_ids.size.should == collection.maximum_size
    end
  end

  describe "self.expiring_between" do
    it "finds payment methods expiring between the given dates" do
      next_year = Time.now.year + 1
      collection = Braintree::CreditCard.expiring_between(Time.mktime(next_year, 1), Time.mktime(next_year, 12))
      collection.maximum_size.should > 0
      collection.all? { |pm| pm.expired?.should == false }
      collection.all? { |pm| pm.expiration_year.should == next_year.to_s }
    end

    it "can iterate over all items" do
      customer = Braintree::Customer.all.first

      (110 - Braintree::CreditCard.expiring_between(Time.mktime(2010, 1, 1), Time.mktime(2010,3, 1)).maximum_size).times do
        Braintree::CreditCard.create!(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "01/2010"
        )
      end

      collection = Braintree::CreditCard.expiring_between(Time.mktime(2010, 1, 1), Time.mktime(2010,3, 1))
      collection.maximum_size.should > 100

      credit_card_ids = collection.map {|c| c.token }.uniq.compact
      credit_card_ids.size.should == collection.maximum_size
    end
  end

  describe "self.find" do
    it "finds the payment method with the given token" do
      customer = Braintree::Customer.create.customer
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      )
      result.success?.should == true
      credit_card = Braintree::CreditCard.find(result.credit_card.token)
      credit_card.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      credit_card.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      credit_card.token.should == result.credit_card.token
      credit_card.expiration_date.should == "05/2012"
    end

    it "returns associated subscriptions with the credit card" do
      customer = Braintree::Customer.create.customer
      credit_card = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      ).credit_card

      subscription = Braintree::Subscription.create(
        :payment_method_token => credit_card.token,
        :plan_id => "integration_trialless_plan",
        :price => "1.00"
      ).subscription

      found_card = Braintree::CreditCard.find(credit_card.token)
      found_card.subscriptions.first.id.should == subscription.id
      found_card.subscriptions.first.plan_id.should == "integration_trialless_plan"
      found_card.subscriptions.first.payment_method_token.should == credit_card.token
      found_card.subscriptions.first.price.should == BigDecimal("1.00")
    end

    it "raises a NotFoundError exception if payment method cannot be found" do
      expect do
        Braintree::CreditCard.find("invalid-token")
      end.to raise_error(Braintree::NotFoundError, 'payment method with token "invalid-token" not found')
    end

    it "raises a NotFoundError exception if searching for a PayPalAccount token" do
      customer = Braintree::Customer.create!
      paypal_account_token = "PAYPAL_ACCOUNT_TOKEN_#{rand(36**3).to_s(36)}"
      paypal_nonce = nonce_for_paypal_account({
          :consent_code => "PAYPAL_CONSENT_CODE",
          :token => paypal_account_token
      })

      Braintree::PaymentMethod.create({
        :payment_method_nonce => paypal_nonce,
        :customer_id => customer.id
      })

      expect do
        Braintree::CreditCard.find(paypal_account_token)
      end.to raise_error(Braintree::NotFoundError, "payment method with token \"#{paypal_account_token}\" not found")
    end
  end

  describe "self.from_nonce" do
    it "finds the payment method with the given nonce" do
      customer = Braintree::Customer.create!
      nonce = nonce_for_new_payment_method(
        :credit_card => {
          :number => "4111111111111111",
          :expiration_month => "11",
          :expiration_year => "2099",
        },
        :client_token_options => {:customer_id => customer.id}
      )

      credit_card = Braintree::CreditCard.from_nonce(nonce)
      customer = Braintree::Customer.find(customer.id)
      credit_card.should == customer.credit_cards.first
    end

    it "does not find a payment method for an unlocked nonce that points to a shared credit card" do
      nonce = nonce_for_new_payment_method(
        :credit_card => {
          :number => "4111111111111111",
          :expiration_month => "11",
          :expiration_year => "2099",
        }
      )
      expect do
        Braintree::CreditCard.from_nonce(nonce)
      end.to raise_error(Braintree::NotFoundError)
    end

    it "does not find the payment method for a consumednonce" do
      customer = Braintree::Customer.create!
      nonce = nonce_for_new_payment_method(
        :credit_card => {
          :number => "4111111111111111",
          :expiration_month => "11",
          :expiration_year => "2099",
        },
        :client_token_options => {:customer_id => customer.id}
      )

      Braintree::CreditCard.from_nonce(nonce)
      expect do
        Braintree::CreditCard.from_nonce(nonce)
      end.to raise_error(Braintree::NotFoundError, /consumed/)
    end
  end

  describe "self.sale" do
    it "creates a sale transaction using the credit card, returning a result object" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )
      result = Braintree::CreditCard.sale(customer.credit_cards[0].token, :amount => "100.00")

      result.success?.should == true
      result.transaction.amount.should == BigDecimal("100.00")
      result.transaction.type.should == "sale"
      result.transaction.customer_details.id.should == customer.id
      result.transaction.credit_card_details.token.should == customer.credit_cards[0].token
      result.transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      result.transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      result.transaction.credit_card_details.expiration_date.should == "05/2010"
    end

    it "allows passing a cvv in addition to the token" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )
      result = Braintree::CreditCard.sale(customer.credit_cards[0].token,
        :amount => "100.00",
        :credit_card => {
          :cvv => "301"
        }
      )

      result.success?.should == true
      result.transaction.amount.should == BigDecimal("100.00")
      result.transaction.type.should == "sale"
      result.transaction.customer_details.id.should == customer.id
      result.transaction.credit_card_details.token.should == customer.credit_cards[0].token
      result.transaction.cvv_response_code.should == "S"
    end
  end

  describe "self.sale!" do
    it "creates a sale transaction using the credit card, returning the transaction" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )
      transaction = Braintree::CreditCard.sale!(customer.credit_cards[0].token, :amount => "100.00")
      transaction.amount.should == BigDecimal("100.00")
      transaction.type.should == "sale"
      transaction.customer_details.id.should == customer.id
      transaction.credit_card_details.token.should == customer.credit_cards[0].token
      transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      transaction.credit_card_details.expiration_date.should == "05/2010"
    end
  end

  describe "sale" do
    it "creates a sale transaction using the credit card, returning a result object" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )
      result = customer.credit_cards[0].sale(
        :amount => "100.00"
      )
      result.success?.should == true
      result.transaction.amount.should == BigDecimal("100.00")
      result.transaction.type.should == "sale"
      result.transaction.customer_details.id.should == customer.id
      result.transaction.credit_card_details.token.should == customer.credit_cards[0].token
      result.transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      result.transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      result.transaction.credit_card_details.expiration_date.should == "05/2010"
    end
  end

  describe "sale!" do
    it "returns the created sale tranaction if valid" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )
      transaction = customer.credit_cards[0].sale!(:amount => "100.00")
      transaction.amount.should == BigDecimal("100.00")
      transaction.type.should == "sale"
      transaction.customer_details.id.should == customer.id
      transaction.credit_card_details.token.should == customer.credit_cards[0].token
      transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      transaction.credit_card_details.expiration_date.should == "05/2010"
    end

    it "raises a ValidationsFailed if invalid" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )
      expect do
        customer.credit_cards[0].sale!(:amount => "invalid")
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "update" do
    it "updates the credit card" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :cardholder_name => "Original Holder",
        :customer_id => customer.id,
        :cvv => "123",
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      )
      update_result = credit_card.update(
        :cardholder_name => "New Holder",
        :cvv => "456",
        :number => Braintree::Test::CreditCardNumbers::MasterCard,
        :expiration_date => "06/2013"
      )
      update_result.success?.should == true
      update_result.credit_card.should == credit_card
      updated_credit_card = update_result.credit_card
      updated_credit_card.bin.should == Braintree::Test::CreditCardNumbers::MasterCard[0, 6]
      updated_credit_card.last_4.should == Braintree::Test::CreditCardNumbers::MasterCard[-4..-1]
      updated_credit_card.expiration_date.should == "06/2013"
      updated_credit_card.cardholder_name.should == "New Holder"
    end

    it "verifies the update if options[verify_card]=true" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :cardholder_name => "Original Holder",
        :customer_id => customer.id,
        :cvv => "123",
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      )
      update_result = credit_card.update(
        :cardholder_name => "New Holder",
        :cvv => "456",
        :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::MasterCard,
        :expiration_date => "06/2013",
        :options => {:verify_card => true}
      )
      update_result.success?.should == false
      update_result.credit_card_verification.status.should == Braintree::Transaction::Status::ProcessorDeclined
    end

    it "fails on create if credit_card[options][fail_on_duplicate_payment_method]=true and there is a duplicated payment method" do
      customer = Braintree::Customer.create!
      Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2015"
      )

      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2015",
        :options => {:fail_on_duplicate_payment_method => true}
      )

      result.success?.should == false
      result.errors.for(:credit_card).on(:number)[0].message.should == "Duplicate card exists in the vault."
    end

    it "allows user to specify merchant account for verification" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :cardholder_name => "Original Holder",
        :customer_id => customer.id,
        :cvv => "123",
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      )
      update_result = credit_card.update(
        :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
        :expiration_date => "05/2009",
        :options => {
          :verify_card => true,
          :verification_merchant_account_id => SpecHelper::NonDefaultMerchantAccountId
        }
      )
      update_result.success?.should == false
      update_result.credit_card_verification.status.should == Braintree::Transaction::Status::ProcessorDeclined
      update_result.credit_card_verification.processor_response_code.should == "2000"
      update_result.credit_card_verification.processor_response_text.should == "Do Not Honor"
      update_result.credit_card_verification.cvv_response_code.should == "I"
      update_result.credit_card_verification.avs_error_response_code.should == nil
      update_result.credit_card_verification.avs_postal_code_response_code.should == "I"
      update_result.credit_card_verification.avs_street_address_response_code.should == "I"
    end

    it "can update the billing address" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :cardholder_name => "Original Holder",
        :customer_id => customer.id,
        :cvv => "123",
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012",
        :billing_address => {
          :first_name => "Old First Name",
          :last_name => "Old Last Name",
          :company => "Old Company",
          :street_address => "123 Old St",
          :extended_address => "Apt Old",
          :locality => "Old City",
          :region => "Old State",
          :postal_code => "12345",
          :country_name => "Canada"
        }
      )
      result = credit_card.update(
        :options => {:verify_card => false},
        :billing_address => {
          :first_name => "New First Name",
          :last_name => "New Last Name",
          :company => "New Company",
          :street_address => "123 New St",
          :extended_address => "Apt New",
          :locality => "New City",
          :region => "New State",
          :postal_code => "56789",
          :country_name => "United States of America"
        }
      )
      result.success?.should == true
      address = result.credit_card.billing_address
      address.should == credit_card.billing_address # making sure credit card instance was updated
      address.first_name.should == "New First Name"
      address.last_name.should == "New Last Name"
      address.company.should == "New Company"
      address.street_address.should == "123 New St"
      address.extended_address.should == "Apt New"
      address.locality.should == "New City"
      address.region.should == "New State"
      address.postal_code.should == "56789"
      address.country_name.should == "United States of America"
    end

    it "returns an error response if invalid" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :cardholder_name => "Original Holder",
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      )
      update_result = credit_card.update(
        :cardholder_name => "New Holder",
        :number => "invalid",
        :expiration_date => "05/2014"
      )
      update_result.success?.should == false
      update_result.errors.for(:credit_card).on(:number)[0].message.should == "Credit card number must be 12-19 digits."
    end
  end

  describe "update!" do
    it "updates the credit card and returns true if valid" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :cardholder_name => "Original Holder",
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      )
      credit_card.update!(
        :cardholder_name => "New Holder",
        :number => Braintree::Test::CreditCardNumbers::MasterCard,
        :expiration_date => "06/2013"
      ).should == credit_card
      credit_card.bin.should == Braintree::Test::CreditCardNumbers::MasterCard[0, 6]
      credit_card.last_4.should == Braintree::Test::CreditCardNumbers::MasterCard[-4..-1]
      credit_card.expiration_date.should == "06/2013"
      credit_card.cardholder_name.should == "New Holder"
      credit_card.updated_at.between?(Time.now - 60, Time.now).should == true
    end

    it "raises a ValidationsFailed if invalid" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :cardholder_name => "Original Holder",
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      )
      expect do
        credit_card.update!(
          :cardholder_name => "New Holder",
          :number => Braintree::Test::CreditCardNumbers::MasterCard,
          :expiration_date => "invalid/date"
        )
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "nonce" do
    it "returns the credit card nonce" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create!(
        :cardholder_name => "Original Holder",
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2012"
      )

      credit_card.nonce.should_not be_nil
    end
  end

  describe "card on file network tokenization" do
    it "should find a network tokenized credit card" do
      credit_card = Braintree::CreditCard.find("network_tokenized_credit_card")
      credit_card.is_network_tokenized?.should == true
    end

    it "should find a non-network tokenized credit card" do
      customer = Braintree::Customer.create!
      credit_card = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2009"
      ).credit_card
      credit_card_vaulted = Braintree::CreditCard.find(credit_card.token)
      credit_card_vaulted.is_network_tokenized?.should == false
    end
  end
end
