require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require File.expand_path(File.dirname(__FILE__) + "/client_api/spec_helper")

describe Braintree::Transaction do
  describe "self.clone_transaction" do
    it "creates a new transaction from the card of the transaction to clone" do
      result = Braintree::Transaction.sale(
        :amount => "112.44",
        :customer => {
          :last_name => "Adama",
        },
        :credit_card => {
          :number => "5105105105105100",
          :expiration_date => "05/2012"
        },
        :billing => {
          :country_name => "Botswana",
          :country_code_alpha2 => "BW",
          :country_code_alpha3 => "BWA",
          :country_code_numeric => "072"
        },
        :shipping => {
          :country_name => "Bhutan",
          :country_code_alpha2 => "BT",
          :country_code_alpha3 => "BTN",
          :country_code_numeric => "064"
        }
      )
      result.success?.should == true

      clone_result = Braintree::Transaction.clone_transaction(
        result.transaction.id,
        :amount => "112.44",
        :channel => "MyShoppingCartProvider",
        :options => {
          :submit_for_settlement => false
        }
      )
      clone_result.success?.should == true

      transaction = clone_result.transaction

      transaction.id.should_not == result.transaction.id
      transaction.amount.should == BigDecimal("112.44")
      transaction.channel.should == "MyShoppingCartProvider"

      transaction.billing_details.country_name.should == "Botswana"
      transaction.billing_details.country_code_alpha2.should == "BW"
      transaction.billing_details.country_code_alpha3.should == "BWA"
      transaction.billing_details.country_code_numeric.should == "072"

      transaction.shipping_details.country_name.should == "Bhutan"
      transaction.shipping_details.country_code_alpha2.should == "BT"
      transaction.shipping_details.country_code_alpha3.should == "BTN"
      transaction.shipping_details.country_code_numeric.should == "064"

      transaction.credit_card_details.masked_number.should == "510510******5100"
      transaction.credit_card_details.expiration_date.should == "05/2012"

      transaction.customer_details.last_name.should == "Adama"
      transaction.status.should == Braintree::Transaction::Status::Authorized
    end

    it "submit for settlement option" do
      result = Braintree::Transaction.sale(
        :amount => "112.44",
        :credit_card => {
          :number => "5105105105105100",
          :expiration_date => "05/2012"
        }
      )

      result.success?.should be(true)

      clone_result = Braintree::Transaction.clone_transaction(result.transaction.id, :amount => "112.44", :options => {:submit_for_settlement => true})
      clone_result.success?.should == true

      clone_result.transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
    end

    it "handles validation errors" do
      transaction = Braintree::Transaction.credit!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      result = Braintree::Transaction.clone_transaction(transaction.id, :amount => "112.44")
      result.success?.should be(false)

      result.errors.for(:transaction).on(:base).first.code.should == Braintree::ErrorCodes::Transaction::CannotCloneCredit
    end
  end

  describe "self.clone_transaction!" do
    it "returns the transaction if valid" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      clone_transaction = Braintree::Transaction.clone_transaction!(transaction.id, :amount => "112.44", :options => {:submit_for_settlement => false})
      clone_transaction.id.should_not == transaction.id
    end

    it "raises a validationsfailed if invalid" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      expect do
        clone_transaction = Braintree::Transaction.clone_transaction!(transaction.id, :amount => "im not a number")
        clone_transaction.id.should_not == transaction.id
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "self.create" do
    describe "risk data" do
      it "returns decision, device_data_captured and id" do
        with_advanced_fraud_integration_merchant do
          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => 1_00,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::CardTypeIndicators::Prepaid,
              :expiration_date => "05/2009"
            }
          )
          result.transaction.risk_data.should be_a(Braintree::RiskData)
          result.transaction.risk_data.should respond_to(:id)
          result.transaction.risk_data.should respond_to(:decision)
          result.transaction.risk_data.should respond_to(:device_data_captured)
          result.transaction.risk_data.should respond_to(:fraud_service_provider)
        end
      end

      it "handles validation errors for invalid risk data attributes" do
        with_advanced_fraud_integration_merchant do
          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "05/2009"
            },
            :risk_data => {
              :customer_browser => "#{"1" * 300}",
              :customer_device_id => "customer_device_id_0#{"1" * 300}",
              :customer_ip => "192.168.0.1",
              :customer_location_zip => "not-a-$#phone",
              :customer_tenure => "20#{"0" * 500}"
            }
          )
          result.success?.should == false
          result.errors.for(:transaction).for(:risk_data).on(:customer_browser).map { |e| e.code }.should include Braintree::ErrorCodes::RiskData::CustomerBrowserIsTooLong
          result.errors.for(:transaction).for(:risk_data).on(:customer_device_id).map { |e| e.code }.should include Braintree::ErrorCodes::RiskData::CustomerDeviceIdIsTooLong
          result.errors.for(:transaction).for(:risk_data).on(:customer_location_zip).map { |e| e.code }.should include Braintree::ErrorCodes::RiskData::CustomerLocationZipInvalidCharacters
          result.errors.for(:transaction).for(:risk_data).on(:customer_tenure).map { |e| e.code }.should include Braintree::ErrorCodes::RiskData::CustomerTenureIsTooLong
        end
      end
    end

    describe "card type indicators" do
      it "sets the prepaid field if the card is prepaid" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => 1_00,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::CardTypeIndicators::Prepaid,
            :expiration_date => "05/2009"
          }
        )
        result.transaction.credit_card_details.prepaid.should == Braintree::CreditCard::Prepaid::Yes
        result.transaction.payment_instrument_type.should == Braintree::PaymentInstrumentType::CreditCard
      end
    end

    describe "industry data" do
      context "for lodging" do
        it "accepts valid industry data" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => 1000_00,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::CardTypeIndicators::Prepaid,
              :expiration_date => "05/2009"
            },
            :industry => {
              :industry_type => Braintree::Transaction::IndustryType::Lodging,
              :data => {
                :folio_number => "ABCDEFG",
                :check_in_date => "2014-06-01",
                :check_out_date => "2014-06-05",
                :room_rate => 170_00,
                :room_tax => 30_00,
                :no_show => false,
                :advanced_deposit => false,
                :fire_safe => true,
                :property_phone => "1112223345",
                :additional_charges => [
                  {
                    :kind => Braintree::Transaction::AdditionalCharge::Telephone,
                    :amount => 50_00,
                  },
                  {
                    :kind => Braintree::Transaction::AdditionalCharge::Other,
                    :amount => 150_00,
                  },
                ],
              }
            }
          )
          result.success?.should be(true)
        end

        it "returns errors if validations on industry lodging data fails" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => 500_00,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::CardTypeIndicators::Prepaid,
              :expiration_date => "05/2009"
            },
            :industry => {
              :industry_type => Braintree::Transaction::IndustryType::Lodging,
              :data => {
                :folio_number => "foo bar",
                :check_in_date => "2014-06-30",
                :check_out_date => "2014-06-01",
                :room_rate => "asdfasdf",
                :additional_charges => [
                  {
                    :kind => "unknown",
                    :amount => 20_00,
                  },
                ],
              }
            }
          )
          result.success?.should be(false)
          invalid_folio = Braintree::ErrorCodes::Transaction::Industry::Lodging::FolioNumberIsInvalid
          check_out_date_must_follow_check_in_date = Braintree::ErrorCodes::Transaction::Industry::Lodging::CheckOutDateMustFollowCheckInDate
          room_rate_format_is_invalid = Braintree::ErrorCodes::Transaction::Industry::Lodging::RoomRateFormatIsInvalid
          invalid_additional_charge_kind = Braintree::ErrorCodes::Transaction::Industry::AdditionalCharge::KindIsInvalid
          result.errors.for(:transaction).for(:industry).map { |e| e.code }.sort.should include *[invalid_folio, check_out_date_must_follow_check_in_date, room_rate_format_is_invalid]
          result.errors.for(:transaction).for(:industry).for(:additional_charges).for(:index_0).on(:kind).map { |e| e.code }.sort.should include *[invalid_additional_charge_kind]
        end
      end

      context "for travel cruise" do
        it "accepts valid industry data" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => 1_00,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::CardTypeIndicators::Prepaid,
              :expiration_date => "05/2009"
            },
            :industry => {
              :industry_type => Braintree::Transaction::IndustryType::TravelAndCruise,
              :data => {
                :travel_package => "flight",
                :departure_date => "2014-07-01",
                :lodging_check_in_date => "2014-07-07",
                :lodging_check_out_date => "2014-07-07",
                :lodging_name => "Royal Caribbean",
              }
            }
          )
          result.success?.should be(true)
        end

        it "returns errors if validations on industry data fails" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => 1_00,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::CardTypeIndicators::Prepaid,
              :expiration_date => "05/2009"
            },
            :industry => {
              :industry_type => Braintree::Transaction::IndustryType::TravelAndCruise,
              :data => {
                :lodging_name => "Royal Caribbean"
              }
            }
          )
          result.success?.should be(false)
          result.errors.for(:transaction).for(:industry).map { |e| e.code }.sort.should == [Braintree::ErrorCodes::Transaction::Industry::TravelCruise::TravelPackageIsInvalid]
        end
      end

      context "for travel flight" do
        it "accepts valid industry data" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => 1_00,
            :payment_method_nonce => Braintree::Test::Nonce::PayPalOneTimePayment,
            :options => {
              :submit_for_settlement => true
            },
            :industry => {
              :industry_type => Braintree::Transaction::IndustryType::TravelAndFlight,
              :data => {
                :passenger_first_name => "John",
                :passenger_last_name => "Doe",
                :passenger_middle_initial => "M",
                :passenger_title => "Mr.",
                :issued_date => Date.new(2018, 1, 1),
                :travel_agency_name => "Expedia",
                :travel_agency_code => "12345678",
                :ticket_number => "ticket-number",
                :issuing_carrier_code => "AA",
                :customer_code => "customer-code",
                :fare_amount => 70_00,
                :fee_amount => 10_00,
                :tax_amount => 20_00,
                :restricted_ticket => false,
                :legs => [
                  {
                    :conjunction_ticket => "CJ0001",
                    :exchange_ticket => "ET0001",
                    :coupon_number => "1",
                    :service_class => "Y",
                    :carrier_code => "AA",
                    :fare_basis_code => "W",
                    :flight_number => "AA100",
                    :departure_date => Date.new(2018, 1, 2),
                    :departure_airport_code => "MDW",
                    :departure_time => "08:00",
                    :arrival_airport_code => "ATX",
                    :arrival_time => "10:00",
                    :stopover_permitted => false,
                    :fare_amount => 35_00,
                    :fee_amount => 5_00,
                    :tax_amount => 10_00,
                    :endorsement_or_restrictions => "NOT REFUNDABLE"
                  },
                  {
                    :conjunction_ticket => "CJ0002",
                    :exchange_ticket => "ET0002",
                    :coupon_number => "1",
                    :service_class => "Y",
                    :carrier_code => "AA",
                    :fare_basis_code => "W",
                    :flight_number => "AA200",
                    :departure_date => Date.new(2018, 1, 3),
                    :departure_airport_code => "ATX",
                    :departure_time => "12:00",
                    :arrival_airport_code => "MDW",
                    :arrival_time => "14:00",
                    :stopover_permitted => false,
                    :fare_amount => 35_00,
                    :fee_amount => 5_00,
                    :tax_amount => 10_00,
                    :endorsement_or_restrictions => "NOT REFUNDABLE"
                  }
                ]
              }
            }
          )
          result.success?.should be(true)
        end

        it "returns errors if validations on industry data fails" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => 1_00,
            :payment_method_nonce => Braintree::Test::Nonce::PayPalOneTimePayment,
            :options => {
              :submit_for_settlement => true
            },
            :industry => {
              :industry_type => Braintree::Transaction::IndustryType::TravelAndFlight,
              :data => {
                :fare_amount => -1_23,
                :restricted_ticket => false,
                :legs => [
                  {
                    :fare_amount => -1_23
                  }
                ]
              }
            }
          )
          result.success?.should be(false)
          result.errors.for(:transaction).for(:industry).map { |e| e.code }.sort.should == [Braintree::ErrorCodes::Transaction::Industry::TravelFlight::FareAmountCannotBeNegative]
          result.errors.for(:transaction).for(:industry).for(:legs).for(:index_0).map { |e| e.code }.sort.should == [Braintree::ErrorCodes::Transaction::Industry::Leg::TravelFlight::FareAmountCannotBeNegative]
        end
      end
    end

    context "elo" do
      it "returns a successful result if successful" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :merchant_account_id => SpecHelper::AdyenMerchantAccountId,
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Elo,
            :cvv => "737",
            :expiration_date => "10/2020"
          }
        )
        result.success?.should == true
        result.transaction.id.should =~ /^\w{6,}$/
        result.transaction.type.should == "sale"
        result.transaction.amount.should == BigDecimal(Braintree::Test::TransactionAmounts::Authorize)
        result.transaction.processor_authorization_code.should_not be_nil
        result.transaction.voice_referral_number.should be_nil
        result.transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Elo[0, 6]
        result.transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Elo[-4..-1]
        result.transaction.credit_card_details.expiration_date.should == "10/2020"
        result.transaction.credit_card_details.customer_location.should == "US"
      end
    end

    it "returns a successful result if successful" do
      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      result.success?.should == true
      result.transaction.id.should =~ /^\w{6,}$/
      result.transaction.type.should == "sale"
      result.transaction.amount.should == BigDecimal(Braintree::Test::TransactionAmounts::Authorize)
      result.transaction.processor_authorization_code.should_not be_nil
      result.transaction.processor_response_code.should == "1000"
      result.transaction.processor_response_text.should == "Approved"
      result.transaction.processor_response_type.should == Braintree::ProcessorResponseTypes::Approved
      result.transaction.voice_referral_number.should be_nil
      result.transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      result.transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      result.transaction.credit_card_details.expiration_date.should == "05/2009"
      result.transaction.credit_card_details.customer_location.should == "US"
      result.transaction.retrieval_reference_number.should_not be_nil
    end

    it "returns a successful network response code if successful" do
      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      expect(result.success?).to eq(true)
      expect(result.transaction.type).to eq("sale")
      expect(result.transaction.amount).to eq(BigDecimal(Braintree::Test::TransactionAmounts::Authorize))
      expect(result.transaction.processor_authorization_code).not_to be_nil
      expect(result.transaction.processor_response_code).to eq("1000")
      expect(result.transaction.processor_response_text).to eq("Approved")
      expect(result.transaction.processor_response_type).to eq(Braintree::ProcessorResponseTypes::Approved)
      expect(result.transaction.network_response_code).to eq("XX")
      expect(result.transaction.network_response_text).to eq("sample network response text")
      expect(result.transaction.voice_referral_number).to be_nil
      expect(result.transaction.credit_card_details.bin).to eq(Braintree::Test::CreditCardNumbers::Visa[0, 6])
      expect(result.transaction.credit_card_details.last_4).to eq(Braintree::Test::CreditCardNumbers::Visa[-4..-1])
      expect(result.transaction.credit_card_details.expiration_date).to eq("05/2009")
      expect(result.transaction.credit_card_details.customer_location).to eq("US")
    end

    it "returns a successful result using an access token" do
      oauth_gateway = Braintree::Gateway.new(
        :client_id => "client_id$#{Braintree::Configuration.environment}$integration_client_id",
        :client_secret => "client_secret$#{Braintree::Configuration.environment}$integration_client_secret",
        :logger => Logger.new("/dev/null")
      )
      access_token = Braintree::OAuthTestHelper.create_token(oauth_gateway, {
        :merchant_public_id => "integration_merchant_id",
        :scope => "read_write"
      }).credentials.access_token

      gateway = Braintree::Gateway.new(
        :access_token => access_token,
        :logger => Logger.new("/dev/null")
      )

      result = gateway.transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )

      result.success?.should == true
      result.transaction.id.should =~ /^\w{6,}$/
      result.transaction.type.should == "sale"
      result.transaction.amount.should == BigDecimal(Braintree::Test::TransactionAmounts::Authorize)
      result.transaction.processor_authorization_code.should_not be_nil
      result.transaction.voice_referral_number.should be_nil
      result.transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      result.transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      result.transaction.credit_card_details.expiration_date.should == "05/2009"
      result.transaction.credit_card_details.customer_location.should == "US"
    end

    it "accepts additional security parameters: device_session_id and fraud_merchant_id" do
      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        },
        :device_session_id => "abc123",
        :fraud_merchant_id => "7"
      )

      result.success?.should == true
    end

    it "accepts additional security parameters: risk data" do
      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        },
        :risk_data => {
          :customer_browser => "IE6",
          :customer_device_id => "customer_device_id_012",
          :customer_ip => "192.168.0.1",
          :customer_location_zip => "91244",
          :customer_tenure => "20",
        }
      )

      result.success?.should == true
    end

    it "accepts billing_address_id in place of billing_address" do
      result = Braintree::Customer.create()
      address_result = Braintree::Address.create(
        :customer_id => result.customer.id,
        :country_code_alpha2 => "US"
      )

      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :customer_id => result.customer.id,
        :billing_address_id => address_result.address.id,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )

      result.success?.should == true
    end

    it "returns processor response code and text as well as the additional processor response if soft declined" do
      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Decline,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      result.success?.should == false
      result.transaction.id.should =~ /^\w{6,}$/
      result.transaction.type.should == "sale"
      result.transaction.status.should == Braintree::Transaction::Status::ProcessorDeclined
      result.transaction.processor_response_code.should == "2000"
      result.transaction.processor_response_text.should == "Do Not Honor"
      result.transaction.processor_response_type.should == Braintree::ProcessorResponseTypes::SoftDeclined
      result.transaction.additional_processor_response.should == "2000 : Do Not Honor"
    end

    it "returns processor response code and text as well as the additional processor response if hard declined" do
      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::HardDecline,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      result.success?.should == false
      result.transaction.id.should =~ /^\w{6,}$/
      result.transaction.type.should == "sale"
      result.transaction.status.should == Braintree::Transaction::Status::ProcessorDeclined
      result.transaction.processor_response_code.should == "2015"
      result.transaction.processor_response_text.should == "Transaction Not Allowed"
      result.transaction.processor_response_type.should == Braintree::ProcessorResponseTypes::HardDeclined
      result.transaction.additional_processor_response.should == "2015 : Transaction Not Allowed"
    end

    it "accepts all four country codes" do
      result = Braintree::Transaction.sale(
        :amount => "100",
        :customer => {
          :last_name => "Adama",
        },
        :credit_card => {
          :number => "5105105105105100",
          :expiration_date => "05/2012"
        },
        :billing => {
          :country_name => "Botswana",
          :country_code_alpha2 => "BW",
          :country_code_alpha3 => "BWA",
          :country_code_numeric => "072"
        },
        :shipping => {
          :country_name => "Bhutan",
          :country_code_alpha2 => "BT",
          :country_code_alpha3 => "BTN",
          :country_code_numeric => "064"
        },
        :options => {
          :add_billing_address_to_payment_method => true,
          :store_in_vault => true
        }
      )
      result.success?.should == true
      transaction = result.transaction
      transaction.billing_details.country_name.should == "Botswana"
      transaction.billing_details.country_code_alpha2.should == "BW"
      transaction.billing_details.country_code_alpha3.should == "BWA"
      transaction.billing_details.country_code_numeric.should == "072"

      transaction.shipping_details.country_name.should == "Bhutan"
      transaction.shipping_details.country_code_alpha2.should == "BT"
      transaction.shipping_details.country_code_alpha3.should == "BTN"
      transaction.shipping_details.country_code_numeric.should == "064"

      transaction.vault_credit_card.billing_address.country_name.should == "Botswana"
      transaction.vault_credit_card.billing_address.country_code_alpha2.should == "BW"
      transaction.vault_credit_card.billing_address.country_code_alpha3.should == "BWA"
      transaction.vault_credit_card.billing_address.country_code_numeric.should == "072"
    end

    it "returns an error if provided inconsistent country information" do
      result = Braintree::Transaction.sale(
        :amount => "100",
        :credit_card => {
          :number => "5105105105105100",
          :expiration_date => "05/2012"
        },
        :billing => {
          :country_name => "Botswana",
          :country_code_alpha2 => "US",
        }
      )

      result.success?.should == false
      result.errors.for(:transaction).for(:billing).on(:base).map { |e| e.code }.should include(Braintree::ErrorCodes::Address::InconsistentCountry)
    end

    it "returns an error if given an incorrect alpha2 code" do
      result = Braintree::Transaction.sale(
        :amount => "100",
        :credit_card => {
          :number => "5105105105105100",
          :expiration_date => "05/2012"
        },
        :billing => {
          :country_code_alpha2 => "ZZ"
        }
      )

      result.success?.should == false
      codes = result.errors.for(:transaction).for(:billing).on(:country_code_alpha2).map { |e| e.code }
      codes.should include(Braintree::ErrorCodes::Address::CountryCodeAlpha2IsNotAccepted)
    end

    it "returns an error if given an incorrect alpha3 code" do
      result = Braintree::Transaction.sale(
        :amount => "100",
        :credit_card => {
          :number => "5105105105105100",
          :expiration_date => "05/2012"
        },
        :billing => {
          :country_code_alpha3 => "ZZZ"
        }
      )

      result.success?.should == false
      codes = result.errors.for(:transaction).for(:billing).on(:country_code_alpha3).map { |e| e.code }
      codes.should include(Braintree::ErrorCodes::Address::CountryCodeAlpha3IsNotAccepted)
    end

    it "returns an error if given an incorrect numeric code" do
      result = Braintree::Transaction.sale(
        :amount => "100",
        :credit_card => {
          :number => "5105105105105100",
          :expiration_date => "05/2012"
        },
        :billing => {
          :country_code_numeric => "FOO"
        }
      )

      result.success?.should == false
      codes = result.errors.for(:transaction).for(:billing).on(:country_code_numeric).map { |e| e.code }
      codes.should include(Braintree::ErrorCodes::Address::CountryCodeNumericIsNotAccepted)
    end

    it "returns an error if provided product sku is invalid" do
      result = Braintree::Transaction.sale(
        :amount => "100",
        :credit_card => {
          :number => "5105105105105100",
          :expiration_date => "05/2012"
        },
        :product_sku => "product$ku!",
      )

      result.success?.should == false
      result.errors.for(:transaction).on(:product_sku).map { |e| e.code }.should include(Braintree::ErrorCodes::Transaction::ProductSkuIsInvalid)
    end

    it "returns an error if provided shipping phone number is invalid" do
      result = Braintree::Transaction.sale(
        :amount => "100",
        :credit_card => {
          :number => "5105105105105100",
          :expiration_date => "05/2012"
        },
        :shipping => {
          :phone_number => "123-234-3456=098765"
        }
      )

      result.success?.should == false
      result.errors.for(:transaction).for(:shipping).on(:phone_number).map { |e| e.code }.should include(Braintree::ErrorCodes::Transaction::ShippingPhoneNumberIsInvalid)
    end

    it "returns an error if provided shipping method is invalid" do
      result = Braintree::Transaction.sale(
        :amount => "100",
        :credit_card => {
          :number => "5105105105105100",
          :expiration_date => "05/2012"
        },
        :shipping => {
          :shipping_method => "urgent"
        }
      )

      result.success?.should == false
      result.errors.for(:transaction).for(:shipping).on(:shipping_method).map { |e| e.code }.should include(Braintree::ErrorCodes::Transaction::ShippingMethodIsInvalid)
    end

    it "returns an error if provided billing phone number is invalid" do
      result = Braintree::Transaction.sale(
        :amount => "100",
        :credit_card => {
          :number => "5105105105105100",
          :expiration_date => "05/2012"
        },
        :billing => {
          :phone_number => "123-234-3456=098765"
        }
      )

      result.success?.should == false
      result.errors.for(:transaction).for(:billing).on(:phone_number).map { |e| e.code }.should include(Braintree::ErrorCodes::Transaction::BillingPhoneNumberIsInvalid)
    end

    context "gateway rejection reason" do
      it "exposes the cvv gateway rejection reason" do
        old_merchant = Braintree::Configuration.merchant_id
        old_public_key = Braintree::Configuration.public_key
        old_private_key = Braintree::Configuration.private_key

        begin
          Braintree::Configuration.merchant_id = "processing_rules_merchant_id"
          Braintree::Configuration.public_key = "processing_rules_public_key"
          Braintree::Configuration.private_key = "processing_rules_private_key"

          result = Braintree::Transaction.sale(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "05/2009",
              :cvv => "200"
            }
          )
          result.success?.should == false
          result.transaction.gateway_rejection_reason.should == Braintree::Transaction::GatewayRejectionReason::CVV
        ensure
          Braintree::Configuration.merchant_id = old_merchant
          Braintree::Configuration.public_key = old_public_key
          Braintree::Configuration.private_key = old_private_key
        end
      end

      it "exposes the application incomplete gateway rejection reason" do
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

        gateway = Braintree::Gateway.new(
          :access_token => result.credentials.access_token,
          :logger => Logger.new("/dev/null")
        )

        result = gateway.transaction.create(
          :type => "sale",
          :amount => "4000.00",
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2020"
          }
        )
        result.success?.should == false
        result.transaction.gateway_rejection_reason.should == Braintree::Transaction::GatewayRejectionReason::ApplicationIncomplete
      end

      it "exposes the avs gateway rejection reason" do
        old_merchant = Braintree::Configuration.merchant_id
        old_public_key = Braintree::Configuration.public_key
        old_private_key = Braintree::Configuration.private_key

        begin
          Braintree::Configuration.merchant_id = "processing_rules_merchant_id"
          Braintree::Configuration.public_key = "processing_rules_public_key"
          Braintree::Configuration.private_key = "processing_rules_private_key"

          result = Braintree::Transaction.sale(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :billing => {
              :street_address => "200 Fake Street"
            },
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "05/2009"
            }
          )
          result.success?.should == false
          result.transaction.gateway_rejection_reason.should == Braintree::Transaction::GatewayRejectionReason::AVS
        ensure
          Braintree::Configuration.merchant_id = old_merchant
          Braintree::Configuration.public_key = old_public_key
          Braintree::Configuration.private_key = old_private_key
        end
      end

      it "exposes the avs_and_cvv gateway rejection reason" do
        old_merchant = Braintree::Configuration.merchant_id
        old_public_key = Braintree::Configuration.public_key
        old_private_key = Braintree::Configuration.private_key

        begin
          Braintree::Configuration.merchant_id = "processing_rules_merchant_id"
          Braintree::Configuration.public_key = "processing_rules_public_key"
          Braintree::Configuration.private_key = "processing_rules_private_key"

          result = Braintree::Transaction.sale(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :billing => {
              :postal_code => "20000"
            },
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "05/2009",
              :cvv => "200"
            }
          )
          result.success?.should == false
          result.transaction.gateway_rejection_reason.should == Braintree::Transaction::GatewayRejectionReason::AVSAndCVV
        ensure
          Braintree::Configuration.merchant_id = old_merchant
          Braintree::Configuration.public_key = old_public_key
          Braintree::Configuration.private_key = old_private_key
        end
      end

      it "exposes the fraud gateway rejection reason" do
        with_advanced_fraud_integration_merchant do
          result = Braintree::Transaction.sale(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Fraud,
              :expiration_date => "05/2017",
              :cvv => "333"
            }
          )
          result.success?.should == false
          result.transaction.gateway_rejection_reason.should == Braintree::Transaction::GatewayRejectionReason::Fraud
        end
      end

      it "exposes the risk_threshold gateway rejection reason (via test cc num)" do
        with_advanced_fraud_integration_merchant do
          result = Braintree::Transaction.sale(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::RiskThreshold,
              :expiration_date => "05/2017",
              :cvv => "333"
            }
          )
          result.success?.should == false
          result.transaction.gateway_rejection_reason.should == Braintree::Transaction::GatewayRejectionReason::RiskThreshold
        end
      end

      it "exposes the risk_threshold gateway rejection reason (via test test nonce)" do
        with_advanced_fraud_integration_merchant do
          result = Braintree::Transaction.sale(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :payment_method_nonce => Braintree::Test::Nonce::GatewayRejectedRiskThresholds,
          )
          result.success?.should == false
          result.transaction.gateway_rejection_reason.should == Braintree::Transaction::GatewayRejectionReason::RiskThreshold
        end
      end

      it "exposes the token issuance gateway rejection reason" do
        result = Braintree::Transaction.sale(
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :merchant_account_id => SpecHelper::FakeVenmoAccountMerchantAccountId,
          :payment_method_nonce => Braintree::Test::Nonce::VenmoAccountTokenIssuanceError,
        )
        result.success?.should == false
        result.transaction.gateway_rejection_reason.should == Braintree::Transaction::GatewayRejectionReason::TokenIssuance
      end
    end

    it "accepts credit card expiration month and expiration year" do
      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_month => "05",
          :expiration_year => "2011"
        }
      )
      result.success?.should == true
      result.transaction.credit_card_details.expiration_month.should == "05"
      result.transaction.credit_card_details.expiration_year.should == "2011"
      result.transaction.credit_card_details.expiration_date.should == "05/2011"
    end

    it "returns some error if customer_id is invalid" do
      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Decline,
        :customer_id => 123456789
      )
      result.success?.should == false
      result.errors.for(:transaction).on(:customer_id)[0].code.should == "91510"
      result.message.should == "Customer ID is invalid."
    end

    it "can create custom fields" do
      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        },
        :custom_fields => {
          :store_me => "custom value"
        }
      )
      result.success?.should == true
      result.transaction.custom_fields.should == {:store_me => "custom value"}
    end

    it "returns nil if a custom field is not defined" do
      create_result = Braintree::Transaction.sale(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "12/2012"
        },
        :custom_fields => {
          :store_me => ""
        }
      )

      result = Braintree::Transaction.find(create_result.transaction.id)

      result.custom_fields.should == {}
    end

    it "returns an error if custom_field is not registered" do
      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        },
        :custom_fields => {
          :invalid_key => "custom value"
        }
      )
      result.success?.should == false
      result.errors.for(:transaction).on(:custom_fields)[0].message.should == "Custom field is invalid: invalid_key."
    end

    it "returns the given params if validations fail" do
      params = {
        :transaction => {
          :type => "sale",
          :amount => nil,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          }
        }
      }
      result = Braintree::Transaction.create(params[:transaction])
      result.success?.should == false
      result.params.should == {:transaction => {:type => 'sale', :amount => nil, :credit_card => {:expiration_date => "05/2009"}}}
    end

    it "returns errors if validations fail (tests many errors at once for spec speed)" do
      params = {
        :transaction => {
          :type => "pants",
          :amount => nil,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          },
          :customer_id => "invalid",
          :order_id => "too long" * 250,
          :channel => "too long" * 250,
          :payment_method_token => "too long and doesn't belong to customer" * 250
        }
      }
      result = Braintree::Transaction.create(params[:transaction])
      result.success?.should == false
      result.errors.for(:transaction).on(:base).map{|error| error.code}.should include(Braintree::ErrorCodes::Transaction::PaymentMethodDoesNotBelongToCustomer)
      result.errors.for(:transaction).on(:customer_id)[0].code.should == Braintree::ErrorCodes::Transaction::CustomerIdIsInvalid
      result.errors.for(:transaction).on(:payment_method_token)[0].code.should == Braintree::ErrorCodes::Transaction::PaymentMethodTokenIsInvalid
      result.errors.for(:transaction).on(:type)[0].code.should == Braintree::ErrorCodes::Transaction::TypeIsInvalid
    end

    it "returns an error if amount is negative" do
      params = {
        :transaction => {
          :type => "credit",
          :amount => "-1"
        }
      }
      result = Braintree::Transaction.create(params[:transaction])
      result.success?.should == false
      result.errors.for(:transaction).on(:amount)[0].code.should == Braintree::ErrorCodes::Transaction::AmountCannotBeNegative
    end

    it "returns an error if amount is not supported by processor" do
      result = Braintree::Transaction.create(
        :type => "sale",
        :merchant_account_id => SpecHelper::HiperBRLMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Hiper,
          :expiration_date => "05/2009"
        },
        :amount => "0.20",
        :options => {
          :credit_card => {
            :account_type => "credit",
          }
        }
      )
      result.success?.should == false
      result.errors.for(:transaction).on(:amount)[0].code.should == Braintree::ErrorCodes::Transaction::AmountNotSupportedByProcessor
    end

    it "returns an error if amount is invalid format" do
      params = {
        :transaction => {
          :type => "sale",
          :amount => "shorts"
        }
      }
      result = Braintree::Transaction.create(params[:transaction])
      result.success?.should == false
      result.errors.for(:transaction).on(:amount)[0].code.should == Braintree::ErrorCodes::Transaction::AmountIsInvalid
    end

    it "returns an error if type is not given" do
      params = {
        :transaction => {
          :type => nil
        }
      }
      result = Braintree::Transaction.create(params[:transaction])
      result.success?.should == false
      result.errors.for(:transaction).on(:type)[0].code.should == Braintree::ErrorCodes::Transaction::TypeIsRequired
    end

    it "returns an error if no credit card is given" do
      params = {
        :transaction => {
        }
      }
      result = Braintree::Transaction.create(params[:transaction])
      result.success?.should == false
      result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::CreditCardIsRequired
    end

    it "returns an error if the given payment method token doesn't belong to the customer" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )
      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :customer_id => customer.id,
        :payment_method_token => customer.credit_cards[0].token + "x"
      )
      result.success?.should == false
      result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::PaymentMethodDoesNotBelongToCustomer
    end

    context "new credit card for existing customer" do
      it "allows a new credit card to be used for an existing customer" do
        customer = Braintree::Customer.create!(
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2010"
          }
        )
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :customer_id => customer.id,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12"
          }
        )
        result.success?.should == true
        result.transaction.credit_card_details.masked_number.should == "401288******1881"
        result.transaction.vault_credit_card.should be_nil
      end

      it "allows a new credit card to be used and stored in the vault" do
        customer = Braintree::Customer.create!(
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2010"
          }
        )
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :customer_id => customer.id,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :options => { :store_in_vault => true }
        )
        result.success?.should == true
        result.transaction.credit_card_details.masked_number.should == "401288******1881"
        result.transaction.vault_credit_card.masked_number.should == "401288******1881"
        result.transaction.credit_card_details.unique_number_identifier.should_not be_nil
      end
    end

    it "snapshots plan, add_ons and discounts from subscription" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )

      result = Braintree::Subscription.create(
        :payment_method_token => customer.credit_cards.first.token,
        :plan_id => SpecHelper::TriallessPlan[:id],
        :add_ons => {
          :add => [
            {
              :amount => BigDecimal("11.00"),
              :inherited_from_id => SpecHelper::AddOnIncrease10,
              :quantity => 2,
              :number_of_billing_cycles => 5
            },
            {
              :amount => BigDecimal("21.00"),
              :inherited_from_id => SpecHelper::AddOnIncrease20,
              :quantity => 3,
              :number_of_billing_cycles => 6
            }
          ]
        },
        :discounts => {
          :add => [
            {
              :amount => BigDecimal("7.50"),
              :inherited_from_id => SpecHelper::Discount7,
              :quantity => 2,
              :never_expires => true
            }
          ]
        }
      )

      result.success?.should be(true)
      transaction = result.subscription.transactions.first

      transaction.plan_id.should == SpecHelper::TriallessPlan[:id]

      transaction.add_ons.size.should == 2
      add_ons = transaction.add_ons.sort_by { |add_on| add_on.id }

      add_ons.first.id.should == "increase_10"
      add_ons.first.amount.should == BigDecimal("11.00")
      add_ons.first.quantity.should == 2
      add_ons.first.number_of_billing_cycles.should == 5
      add_ons.first.never_expires?.should be(false)

      add_ons.last.id.should == "increase_20"
      add_ons.last.amount.should == BigDecimal("21.00")
      add_ons.last.quantity.should == 3
      add_ons.last.number_of_billing_cycles.should == 6
      add_ons.last.never_expires?.should be(false)

      transaction.discounts.size.should == 1

      transaction.discounts.first.id.should == "discount_7"
      transaction.discounts.first.amount.should == BigDecimal("7.50")
      transaction.discounts.first.quantity.should == 2
      transaction.discounts.first.number_of_billing_cycles.should be_nil
      transaction.discounts.first.never_expires?.should be(true)
    end

    context "descriptors" do
      it "accepts name and phone" do
        result = Braintree::Transaction.sale(
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          },
          :descriptor => {
            :name => '123*123456789012345678',
            :phone => '3334445555',
            :url => "ebay.com"
          }
        )
        result.success?.should == true
        result.transaction.descriptor.name.should == '123*123456789012345678'
        result.transaction.descriptor.phone.should == '3334445555'
        result.transaction.descriptor.url.should == 'ebay.com'
      end

      it "has validation errors if format is invalid" do
        result = Braintree::Transaction.sale(
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          },
          :descriptor => {
            :name => 'badcompanyname12*badproduct12',
            :phone => '%bad4445555',
            :url => '12345678901234'
          }
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:descriptor).on(:name)[0].code.should == Braintree::ErrorCodes::Descriptor::NameFormatIsInvalid
        result.errors.for(:transaction).for(:descriptor).on(:phone)[0].code.should == Braintree::ErrorCodes::Descriptor::PhoneFormatIsInvalid
        result.errors.for(:transaction).for(:descriptor).on(:url)[0].code.should == Braintree::ErrorCodes::Descriptor::UrlFormatIsInvalid
      end
    end

    context "level 2 fields" do
      it "accepts tax_amount, tax_exempt, and purchase_order_number" do
        result = Braintree::Transaction.sale(
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          },
          :tax_amount => '0.05',
          :tax_exempt => false,
          :purchase_order_number => '12345678901234567'
        )
        result.success?.should == true
        result.transaction.tax_amount.should == BigDecimal("0.05")
        result.transaction.tax_exempt.should == false
        result.transaction.purchase_order_number.should == '12345678901234567'
      end

      it "accepts tax_amount as a BigDecimal" do
        result = Braintree::Transaction.sale(
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          },
          :tax_amount => BigDecimal('1.99'),
          :tax_exempt => true
        )
        result.success?.should == true
        result.transaction.tax_amount.should == BigDecimal("1.99")
        result.transaction.tax_exempt.should == true
        result.transaction.purchase_order_number.should be_nil
      end

      context "validations" do
        it "tax_amount" do
          result = Braintree::Transaction.sale(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "05/2009"
            },
            :tax_amount => 'abcd'
          )
          result.success?.should == false
          result.errors.for(:transaction).on(:tax_amount)[0].code.should == Braintree::ErrorCodes::Transaction::TaxAmountFormatIsInvalid
        end

        it "purchase_order_number length" do
          result = Braintree::Transaction.sale(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "05/2009"
            },
            :purchase_order_number => 'a' * 18
          )
          result.success?.should == false
          result.errors.for(:transaction).on(:purchase_order_number)[0].code.should == Braintree::ErrorCodes::Transaction::PurchaseOrderNumberIsTooLong
        end

        it "purchase_order_number format" do
          result = Braintree::Transaction.sale(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "05/2009"
            },
            :purchase_order_number => "\303\237\303\245\342\210\202"
          )
          result.success?.should == false
          result.errors.for(:transaction).on(:purchase_order_number)[0].code.should == Braintree::ErrorCodes::Transaction::PurchaseOrderNumberIsInvalid
        end
      end
    end

    context "recurring" do
      it "marks a transaction as recurring" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :recurring => true
        )
        result.success?.should == true
        result.transaction.recurring.should == true
      end
    end

    context "transaction_source" do
      it "marks a transactions as recurring_first" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :transaction_source => "recurring_first"
        )
        result.success?.should == true
        result.transaction.recurring.should == true
      end

      it "marks a transactions as recurring" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :transaction_source => "recurring"
        )
        result.success?.should == true
        result.transaction.recurring.should == true
      end

      it "marks a transactions as merchant" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :transaction_source => "merchant"
        )
        result.success?.should == true
        result.transaction.recurring.should == false
      end

      it "marks a transactions as moto" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :transaction_source => "moto"
        )
        result.success?.should == true
        result.transaction.recurring.should == false
      end

      it "handles validation when transaction source invalid" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :transaction_source => "invalid_value"
        )
        result.success?.should == false
        result.errors.for(:transaction).on(:transaction_source)[0].code.should == Braintree::ErrorCodes::Transaction::TransactionSourceIsInvalid
      end
    end

    context "store_in_vault_on_success" do
      context "passed as true" do
        it "stores vault records when transaction succeeds" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :customer => {
              :last_name => "Doe"
            },
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "12/12",
            },
            :options => { :store_in_vault_on_success => true }
          )
          result.success?.should == true
          result.transaction.vault_customer.last_name.should == "Doe"
          result.transaction.vault_credit_card.masked_number.should == "401288******1881"
          result.transaction.credit_card_details.unique_number_identifier.should_not be_nil
        end

        it "does not store vault records when true and transaction fails" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Decline,
            :customer => {
              :last_name => "Doe"
            },
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "12/12",
            },
            :options => { :store_in_vault_on_success => true }
          )
          result.success?.should == false
          result.transaction.vault_customer.should be_nil
          result.transaction.vault_credit_card.should be_nil
        end
      end

      context "passed as false" do
        it "does not store vault records when transaction succeeds" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :customer => {
              :last_name => "Doe"
            },
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "12/12",
            },
            :options => { :store_in_vault_on_success => false }
          )
          result.success?.should == true
          result.transaction.vault_customer.should be_nil
          result.transaction.vault_credit_card.should be_nil
        end

        it "does not store vault records when transaction fails" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Decline,
            :customer => {
              :last_name => "Doe"
            },
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "12/12",
            },
            :options => { :store_in_vault_on_success => false }
          )
          result.success?.should == false
          result.transaction.vault_customer.should be_nil
          result.transaction.vault_credit_card.should be_nil
        end
      end
    end

    context "service fees" do
      it "allows specifying service fees" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :merchant_account_id => SpecHelper::NonDefaultSubMerchantAccountId,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :service_fee_amount => "1.00"
        )
        result.success?.should == true
        result.transaction.service_fee_amount.should == BigDecimal("1.00")
      end

      it "raises an error if transaction merchant account is a master" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :merchant_account_id => SpecHelper::NonDefaultMerchantAccountId,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :service_fee_amount => "1.00"
        )
        result.success?.should == false
        expected_error_code = Braintree::ErrorCodes::Transaction::ServiceFeeAmountNotAllowedOnMasterMerchantAccount
        result.errors.for(:transaction).on(:service_fee_amount)[0].code.should == expected_error_code
      end

      it "raises an error if no service fee is present on a sub merchant account transaction" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :merchant_account_id => SpecHelper::NonDefaultSubMerchantAccountId,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          }
        )
        result.success?.should == false
        expected_error_code = Braintree::ErrorCodes::Transaction::SubMerchantAccountRequiresServiceFeeAmount
        result.errors.for(:transaction).on(:merchant_account_id)[0].code.should == expected_error_code
      end

      it "raises an error if service fee amount is negative" do
        result = Braintree::Transaction.create(
          :merchant_account_id => SpecHelper::NonDefaultSubMerchantAccountId,
          :service_fee_amount => "-1.00"
        )
        result.success?.should == false
        result.errors.for(:transaction).on(:service_fee_amount)[0].code.should == Braintree::ErrorCodes::Transaction::ServiceFeeAmountCannotBeNegative
      end

      it "raises an error if service fee amount is invalid" do
        result = Braintree::Transaction.create(
          :merchant_account_id => SpecHelper::NonDefaultSubMerchantAccountId,
          :service_fee_amount => "invalid amount"
        )
        result.success?.should == false
        result.errors.for(:transaction).on(:service_fee_amount)[0].code.should == Braintree::ErrorCodes::Transaction::ServiceFeeAmountFormatIsInvalid
      end
    end

    context "escrow" do
      it "allows specifying transactions to be held for escrow" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :merchant_account_id => SpecHelper::NonDefaultSubMerchantAccountId,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :service_fee_amount => "10.00",
          :options => {:hold_in_escrow => true}
        )

        result.success?.should == true
        result.transaction.escrow_status.should == Braintree::Transaction::EscrowStatus::HoldPending
      end

      it "raises an error if transaction merchant account is a master" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :merchant_account_id => SpecHelper::NonDefaultMerchantAccountId,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :service_fee_amount => "1.00",
          :options => {:hold_in_escrow => true}
        )
        result.success?.should == false
        expected_error_code = Braintree::ErrorCodes::Transaction::CannotHoldInEscrow
        result.errors.for(:transaction).on(:base)[0].code.should == expected_error_code
      end
    end

    describe "venmo_sdk" do
      it "can create a card with a venmo sdk payment method code" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :venmo_sdk_payment_method_code => Braintree::Test::VenmoSDK::VisaPaymentMethodCode
        )
        result.success?.should == true
        result.transaction.credit_card_details.bin.should == "400934"
        result.transaction.credit_card_details.last_4.should == "1881"
      end

      it "can create a transaction with venmo sdk session" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :options => {
            :venmo_sdk_session => Braintree::Test::VenmoSDK::Session
          }
        )
        result.success?.should == true
        result.transaction.credit_card_details.venmo_sdk?.should == false
      end
    end

    context "client API" do
      it "can create a transaction with a shared card nonce" do
        nonce = nonce_for_new_payment_method(
          :credit_card => {
            :number => "4111111111111111",
            :expiration_month => "11",
            :expiration_year => "2099",
          },
          :share => true
        )
        nonce.should_not be_nil

        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => nonce
        )
        result.success?.should == true
      end

      it "can create a transaction with a vaulted card nonce" do
        customer = Braintree::Customer.create!
        nonce = nonce_for_new_payment_method(
          :credit_card => {
            :number => "4111111111111111",
            :expiration_month => "11",
            :expiration_year => "2099",
          },
          :client_token_options => {
            :customer_id => customer.id,
          }
        )
        nonce.should_not be_nil

        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => nonce
        )
        result.success?.should == true
      end

      it "can create a transaction with a vaulted PayPal account" do
        customer = Braintree::Customer.create!
        nonce = nonce_for_new_payment_method(
          :paypal_account => {
            :consent_code => "PAYPAL_CONSENT_CODE",
          },
          :client_token_options => {
            :customer_id => customer.id,
          }
        )
        nonce.should_not be_nil

        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => nonce
        )
        result.success?.should == true
        result.transaction.paypal_details.should_not be_nil
        result.transaction.paypal_details.debug_id.should_not be_nil
      end

      it "can create a transaction with a params nonce with PayPal account params" do
        customer = Braintree::Customer.create!
        nonce = nonce_for_new_payment_method(
          :paypal_account => {
            :consent_code => "PAYPAL_CONSENT_CODE",
          }
        )
        nonce.should_not be_nil

        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => nonce
        )
        result.success?.should == true
        result.transaction.paypal_details.should_not be_nil
        result.transaction.paypal_details.debug_id.should_not be_nil
      end

      it "can create a transaction with a fake apple pay nonce" do
        customer = Braintree::Customer.create!
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => Braintree::Test::Nonce::ApplePayVisa
        )
        result.success?.should == true
        result.transaction.should_not be_nil
        apple_pay_details = result.transaction.apple_pay_details
        apple_pay_details.should_not be_nil
        apple_pay_details.bin.should_not be_nil
        apple_pay_details.card_type.should == Braintree::ApplePayCard::CardType::Visa
        apple_pay_details.payment_instrument_name.should == "Visa 8886"
        apple_pay_details.source_description.should == "Visa 8886"
        apple_pay_details.expiration_month.to_i.should > 0
        apple_pay_details.expiration_year.to_i.should > 0
        apple_pay_details.cardholder_name.should_not be_nil
        apple_pay_details.image_url.should_not be_nil
        apple_pay_details.token.should be_nil
        apple_pay_details.prepaid.should_not be_nil
        apple_pay_details.healthcare.should_not be_nil
        apple_pay_details.debit.should_not be_nil
        apple_pay_details.durbin_regulated.should_not be_nil
        apple_pay_details.commercial.should_not be_nil
        apple_pay_details.payroll.should_not be_nil
        apple_pay_details.product_id.should_not be_nil
      end

      it "can create a vaulted transaction with a fake apple pay nonce" do
        customer = Braintree::Customer.create!
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => Braintree::Test::Nonce::ApplePayVisa,
          :options => { :store_in_vault_on_success => true }
        )
        result.success?.should == true
        result.transaction.should_not be_nil
        apple_pay_details = result.transaction.apple_pay_details
        apple_pay_details.should_not be_nil
        apple_pay_details.card_type.should == Braintree::ApplePayCard::CardType::Visa
        apple_pay_details.payment_instrument_name.should == "Visa 8886"
        apple_pay_details.source_description.should == "Visa 8886"
        apple_pay_details.expiration_month.to_i.should > 0
        apple_pay_details.expiration_year.to_i.should > 0
        apple_pay_details.cardholder_name.should_not be_nil
        apple_pay_details.image_url.should_not be_nil
        apple_pay_details.token.should_not be_nil
      end

      it "can create a transaction with a fake android pay proxy card nonce" do
        customer = Braintree::Customer.create!
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => Braintree::Test::Nonce::AndroidPayDiscover
        )
        result.success?.should == true
        result.transaction.should_not be_nil
        android_pay_details = result.transaction.android_pay_details
        android_pay_details.should_not be_nil
        android_pay_details.bin.should_not be_nil
        android_pay_details.card_type.should == Braintree::CreditCard::CardType::Discover
        android_pay_details.virtual_card_type.should == Braintree::CreditCard::CardType::Discover
        android_pay_details.last_4.should == "1117"
        android_pay_details.virtual_card_last_4.should == "1117"
        android_pay_details.source_description.should == "Discover 1111"
        android_pay_details.expiration_month.to_i.should > 0
        android_pay_details.expiration_year.to_i.should > 0
        android_pay_details.google_transaction_id.should == "google_transaction_id"
        android_pay_details.image_url.should_not be_nil
        android_pay_details.is_network_tokenized?.should == false
        android_pay_details.token.should be_nil
        android_pay_details.prepaid.should_not be_nil
        android_pay_details.healthcare.should_not be_nil
        android_pay_details.debit.should_not be_nil
        android_pay_details.durbin_regulated.should_not be_nil
        android_pay_details.commercial.should_not be_nil
        android_pay_details.payroll.should_not be_nil
        android_pay_details.product_id.should_not be_nil
      end

      it "can create a vaulted transaction with a fake android pay proxy card nonce" do
        customer = Braintree::Customer.create!
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => Braintree::Test::Nonce::AndroidPayDiscover,
          :options => { :store_in_vault_on_success => true }
        )
        result.success?.should == true
        result.transaction.should_not be_nil
        android_pay_details = result.transaction.android_pay_details
        android_pay_details.should_not be_nil
        android_pay_details.card_type.should == Braintree::CreditCard::CardType::Discover
        android_pay_details.virtual_card_type.should == Braintree::CreditCard::CardType::Discover
        android_pay_details.last_4.should == "1117"
        android_pay_details.virtual_card_last_4.should == "1117"
        android_pay_details.source_description.should == "Discover 1111"
        android_pay_details.expiration_month.to_i.should > 0
        android_pay_details.expiration_year.to_i.should > 0
        android_pay_details.google_transaction_id.should == "google_transaction_id"
        android_pay_details.image_url.should_not be_nil
        android_pay_details.is_network_tokenized?.should == false
        android_pay_details.token.should_not be_nil
      end

      it "can create a transaction with a fake android pay network token nonce" do
        customer = Braintree::Customer.create!
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => Braintree::Test::Nonce::AndroidPayMasterCard
        )
        result.success?.should == true
        result.transaction.should_not be_nil
        android_pay_details = result.transaction.android_pay_details
        android_pay_details.should_not be_nil
        android_pay_details.card_type.should == Braintree::CreditCard::CardType::MasterCard
        android_pay_details.virtual_card_type.should == Braintree::CreditCard::CardType::MasterCard
        android_pay_details.last_4.should == "4444"
        android_pay_details.virtual_card_last_4.should == "4444"
        android_pay_details.source_description.should == "MasterCard 4444"
        android_pay_details.expiration_month.to_i.should > 0
        android_pay_details.expiration_year.to_i.should > 0
        android_pay_details.google_transaction_id.should == "google_transaction_id"
        android_pay_details.is_network_tokenized?.should == true
      end

      it "can create a transaction with a fake amex express checkout card nonce" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :merchant_account_id => SpecHelper::FakeAmexDirectMerchantAccountId,
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => Braintree::Test::Nonce::AmexExpressCheckout,
          :options => {:store_in_vault => true}
        )
        result.success?.should == true
        result.transaction.should_not be_nil
        checkout_details = result.transaction.amex_express_checkout_details
        checkout_details.should_not be_nil
        checkout_details.card_type.should == "American Express"
        checkout_details.token.should respond_to(:to_str)
        checkout_details.bin.should =~ /\A\d{6}\z/
        checkout_details.expiration_month.should =~ /\A\d{2}\z/
        checkout_details.expiration_year.should =~ /\A\d{4}\z/
        checkout_details.card_member_number.should =~ /\A\d{4}\z/
        checkout_details.card_member_expiry_date.should =~ /\A\d{2}\/\d{2}\z/
        checkout_details.image_url.should include(".png")
        checkout_details.source_description.should =~ /\AAmEx \d{4}\z/
      end

      it "can create a transaction with a fake venmo account nonce" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :merchant_account_id => SpecHelper::FakeVenmoAccountMerchantAccountId,
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => Braintree::Test::Nonce::VenmoAccount,
          :options => {:store_in_vault => true}
        )
        result.should be_success

        result.transaction.payment_instrument_type.should == Braintree::PaymentInstrumentType::VenmoAccount
        venmo_account_details = result.transaction.venmo_account_details
        venmo_account_details.should be_a(Braintree::Transaction::VenmoAccountDetails)
        venmo_account_details.token.should respond_to(:to_str)
        venmo_account_details.username.should == "venmojoe"
        venmo_account_details.venmo_user_id.should == "Venmo-Joe-1"
        venmo_account_details.image_url.should include(".png")
        venmo_account_details.source_description.should == "Venmo Account: venmojoe"
      end

      it "can create a transaction with a fake venmo account nonce specifying a profile" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :merchant_account_id => SpecHelper::FakeVenmoAccountMerchantAccountId,
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => Braintree::Test::Nonce::VenmoAccount,
          :options => {:store_in_vault => true, :venmo => {:profile_id => "integration_venmo_merchant_public_id" }}
        )
        result.should be_success
      end

      it "can create a transaction with an unknown nonce" do
        customer = Braintree::Customer.create!
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => Braintree::Test::Nonce::AbstractTransactable
        )
        result.success?.should == true
        result.transaction.should_not be_nil
      end

      it "can create a transaction with local payment webhook content" do
        result = Braintree::Transaction.sale(
          :amount => "100",
          :options => {
            :submit_for_settlement => true
          },
          :paypal_account => {
            :payer_id => "PAYER-1234",
            :payment_id => "PAY-5678",
          }
        )

        result.success?.should == true
        result.transaction.status.should == Braintree::Transaction::Status::Settling
        result.transaction.paypal_details.payer_id.should == "PAYER-1234"
        result.transaction.paypal_details.payment_id.should == "PAY-5678"
      end

      it "can create a transaction with a payee id" do
        customer = Braintree::Customer.create!
        nonce = nonce_for_new_payment_method(
          :paypal_account => {
            :consent_code => "PAYPAL_CONSENT_CODE",
          }
        )
        nonce.should_not be_nil

        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => nonce,
          :paypal_account => {
            :payee_id => "fake-payee-id"
          }
        )

        result.success?.should == true
        result.transaction.paypal_details.should_not be_nil
        result.transaction.paypal_details.debug_id.should_not be_nil
        result.transaction.paypal_details.payee_id.should == "fake-payee-id"
      end

      it "can create a transaction with a payee id in the options params" do
        customer = Braintree::Customer.create!
        nonce = nonce_for_new_payment_method(
          :paypal_account => {
            :consent_code => "PAYPAL_CONSENT_CODE",
          }
        )
        nonce.should_not be_nil

        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => nonce,
          :paypal_account => {},
          :options => {
            :payee_id => "fake-payee-id"
          }
        )

        result.success?.should == true
        result.transaction.paypal_details.should_not be_nil
        result.transaction.paypal_details.debug_id.should_not be_nil
        result.transaction.paypal_details.payee_id.should == "fake-payee-id"
      end

      it "can create a transaction with a payee id in options.paypal" do
        customer = Braintree::Customer.create!
        nonce = nonce_for_new_payment_method(
          :paypal_account => {
            :consent_code => "PAYPAL_CONSENT_CODE",
          }
        )
        nonce.should_not be_nil

        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => nonce,
          :options => {
            :paypal => {
              :payee_id => "fake-payee-id"
            }
          }
        )

        result.success?.should == true
        result.transaction.paypal_details.should_not be_nil
        result.transaction.paypal_details.debug_id.should_not be_nil
        result.transaction.paypal_details.payee_id.should == "fake-payee-id"
      end

      it "can create a transaction with a payee email" do
        customer = Braintree::Customer.create!
        nonce = nonce_for_new_payment_method(
          :paypal_account => {
            :consent_code => "PAYPAL_CONSENT_CODE",
          }
        )
        nonce.should_not be_nil

        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => nonce,
          :paypal_account => {
            :payee_email => "bt_seller_us@paypal.com"
          }
        )

        result.success?.should == true
        result.transaction.paypal_details.should_not be_nil
        result.transaction.paypal_details.debug_id.should_not be_nil
        result.transaction.paypal_details.payee_email.should == "bt_seller_us@paypal.com"
      end

      it "can create a transaction with a payee email in the options params" do
        customer = Braintree::Customer.create!
        nonce = nonce_for_new_payment_method(
          :paypal_account => {
            :consent_code => "PAYPAL_CONSENT_CODE",
          }
        )
        nonce.should_not be_nil

        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => nonce,
          :paypal_account => {},
          :options => {
            :payee_email => "bt_seller_us@paypal.com"
          }
        )

        result.success?.should == true
        result.transaction.paypal_details.should_not be_nil
        result.transaction.paypal_details.debug_id.should_not be_nil
        result.transaction.paypal_details.payee_email.should == "bt_seller_us@paypal.com"
      end

      it "can create a transaction with a payee email in options.paypal" do
        customer = Braintree::Customer.create!
        nonce = nonce_for_new_payment_method(
          :paypal_account => {
            :consent_code => "PAYPAL_CONSENT_CODE",
          }
        )
        nonce.should_not be_nil

        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => nonce,
          :options => {
            :paypal => {
              :payee_email => "bt_seller_us@paypal.com"
            }
          }
        )

        result.success?.should == true
        result.transaction.paypal_details.should_not be_nil
        result.transaction.paypal_details.debug_id.should_not be_nil
        result.transaction.paypal_details.payee_email.should == "bt_seller_us@paypal.com"
      end

      it "can create a transaction with a paypal custom field" do
        customer = Braintree::Customer.create!
        nonce = nonce_for_new_payment_method(
          :paypal_account => {
            :consent_code => "PAYPAL_CONSENT_CODE",
          }
        )
        nonce.should_not be_nil

        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => nonce,
          :options => {
            :paypal => {
              :custom_field => "Additional info"
            }
          }
        )

        result.success?.should == true
        result.transaction.paypal_details.should_not be_nil
        result.transaction.paypal_details.debug_id.should_not be_nil
        result.transaction.paypal_details.custom_field.should == "Additional info"
      end

      it "can create a transaction with a paypal description" do
        customer = Braintree::Customer.create!
        nonce = nonce_for_new_payment_method(
          :paypal_account => {
            :consent_code => "PAYPAL_CONSENT_CODE",
          }
        )
        nonce.should_not be_nil

        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => nonce,
          :options => {
            :paypal => {
              :description => "A great product"
            }
          }
        )

        result.success?.should == true
        result.transaction.paypal_details.should_not be_nil
        result.transaction.paypal_details.debug_id.should_not be_nil
        result.transaction.paypal_details.description.should == "A great product"
      end

      it "can create a transaction with STC supplementary data" do
        customer = Braintree::Customer.create!
        nonce = nonce_for_new_payment_method(
          :paypal_account => {
            :consent_code => "PAYPAL_CONSENT_CODE",
          }
        )
        nonce.should_not be_nil

        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => nonce,
          :options => {
            :paypal => {
              :supplementary_data => {
                :key1 => "value1",
                :key2 => "value2",
              }
            }
          }
        )

        # note - supplementary data is not returned in response
        result.success?.should == true
      end
    end

    context "three_d_secure" do
      it "can create a transaction with a three_d_secure token" do
        three_d_secure_token = SpecHelper.create_3ds_verification(
          SpecHelper::ThreeDSecureMerchantAccountId,
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_month => "12",
          :expiration_year => "2012"
        )

        result = Braintree::Transaction.create(
          :type => "sale",
          :merchant_account_id => SpecHelper::ThreeDSecureMerchantAccountId,
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :three_d_secure_token => three_d_secure_token
        )

        result.success?.should == true
      end

      it "gateway rejects transactions if 3DS is required but not provided" do
        nonce = nonce_for_new_payment_method(
          :credit_card => {
            :number => "4111111111111111",
            :expiration_month => "11",
            :expiration_year => "2099",
          }
        )
        nonce.should_not be_nil
        result = Braintree::Transaction.create(
          :merchant_account_id => SpecHelper::ThreeDSecureMerchantAccountId,
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :payment_method_nonce => nonce,
          :options => {
            :three_d_secure => {
              :required => true,
            }
          }
        )

        result.success?.should == false
        result.transaction.gateway_rejection_reason.should == Braintree::Transaction::GatewayRejectionReason::ThreeDSecure
      end


      it "can create a transaction without a three_d_secure_authentication_id" do
        result = Braintree::Transaction.create(
          :merchant_account_id => SpecHelper::ThreeDSecureMerchantAccountId,
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          }
        )
        result.success?.should == true
      end

      context "with three_d_secure_authentication_id" do
        it "can create a transaction with a three_d_secure_authentication_id" do
          three_d_secure_authentication_id = SpecHelper.create_3ds_verification(
            SpecHelper::ThreeDSecureMerchantAccountId,
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_month => "12",
            :expiration_year => "2022"
          )

          result = Braintree::Transaction.create(
            :merchant_account_id => SpecHelper::ThreeDSecureMerchantAccountId,
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "12/22",
            },
            :three_d_secure_authentication_id => three_d_secure_authentication_id
          )

          result.success?.should == true
        end
        it "returns an error if sent a nil three_d_secure_authentication_id" do
          result = Braintree::Transaction.create(
            :merchant_account_id => SpecHelper::ThreeDSecureMerchantAccountId,
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "12/12",
            },
            :three_d_secure_authentication_id => nil
          )
          result.success?.should == false
          result.errors.for(:transaction).on(:three_d_secure_authentication_id)[0].code.should == Braintree::ErrorCodes::Transaction::ThreeDSecureAuthenticationIdIsInvalid
        end
        it "returns an error if merchant_account in the payment_method does not match with 3ds data" do
          three_d_secure_authentication_id = SpecHelper.create_3ds_verification(
            SpecHelper::ThreeDSecureMerchantAccountId,
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_month => "12",
            :expiration_year => "2012"
          )

          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::MasterCard,
              :expiration_date => "12/12",
            },
            :three_d_secure_authentication_id => three_d_secure_authentication_id
          )
          result.success?.should == false
          result.errors.for(:transaction).on(:three_d_secure_authentication_id)[0].code.should == Braintree::ErrorCodes::Transaction::ThreeDSecureTransactionPaymentMethodDoesntMatchThreeDSecureAuthenticationPaymentMethod
        end
        it "returns an error if 3ds lookup data does not match txn data" do
          three_d_secure_authentication_id = SpecHelper.create_3ds_verification(
            SpecHelper::ThreeDSecureMerchantAccountId,
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_month => "12",
            :expiration_year => "2012"
          )

          result = Braintree::Transaction.create(
            :merchant_account_id => SpecHelper::ThreeDSecureMerchantAccountId,
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::MasterCard,
              :expiration_date => "12/12",
            },
            :three_d_secure_authentication_id => three_d_secure_authentication_id
          )
          result.success?.should == false
          result.errors.for(:transaction).on(:three_d_secure_authentication_id)[0].code.should == Braintree::ErrorCodes::Transaction::ThreeDSecureTransactionPaymentMethodDoesntMatchThreeDSecureAuthenticationPaymentMethod
        end
        it "returns an error if three_d_secure_authentication_id is supplied with three_d_secure_pass_thru" do
          three_d_secure_authentication_id = SpecHelper.create_3ds_verification(
            SpecHelper::ThreeDSecureMerchantAccountId,
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_month => "12",
            :expiration_year => "2012"
          )
          result = Braintree::Transaction.create(
            :merchant_account_id => SpecHelper::ThreeDSecureMerchantAccountId,
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "12/12",
            },
            :three_d_secure_authentication_id => three_d_secure_authentication_id,
            :three_d_secure_pass_thru => {
              :eci_flag => "02",
              :cavv => "some_cavv",
              :xid => "some_xid",
              :three_d_secure_version => "1.0.2",
              :authentication_response => "Y",
              :directory_response => "Y",
              :cavv_algorithm => "2",
              :ds_transaction_id => "some_ds_id",
            }
          )
          result.success?.should == false
          result.errors.for(:transaction).on(:three_d_secure_authentication_id)[0].code.should == Braintree::ErrorCodes::Transaction::ThreeDSecureAuthenticationIdWithThreeDSecurePassThruIsInvalid
        end
      end

      context "with three_d_secure_token" do
        it "can create a transaction with a three_d_secure token" do
          three_d_secure_token = SpecHelper.create_3ds_verification(
            SpecHelper::ThreeDSecureMerchantAccountId,
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_month => "12",
            :expiration_year => "2012"
          )

          result = Braintree::Transaction.create(
            :merchant_account_id => SpecHelper::ThreeDSecureMerchantAccountId,
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "12/12",
            },
            :three_d_secure_token => three_d_secure_token
          )

          result.success?.should == true
        end

        it "returns an error if sent a nil three_d_secure token" do
          result = Braintree::Transaction.create(
            :merchant_account_id => SpecHelper::ThreeDSecureMerchantAccountId,
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "12/12",
            },
            :three_d_secure_token => nil
          )
          result.success?.should == false
          result.errors.for(:transaction).on(:three_d_secure_token)[0].code.should == Braintree::ErrorCodes::Transaction::ThreeDSecureTokenIsInvalid
        end

        it "returns an error if 3ds lookup data does not match txn data" do
          three_d_secure_token = SpecHelper.create_3ds_verification(
            SpecHelper::ThreeDSecureMerchantAccountId,
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_month => "12",
            :expiration_year => "2012"
          )

          result = Braintree::Transaction.create(
            :merchant_account_id => SpecHelper::ThreeDSecureMerchantAccountId,
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::MasterCard,
              :expiration_date => "12/12",
            },
            :three_d_secure_token => three_d_secure_token
          )
          result.success?.should == false
          result.errors.for(:transaction).on(:three_d_secure_token)[0].code.should == Braintree::ErrorCodes::Transaction::ThreeDSecureTransactionDataDoesntMatchVerify
        end
      end

      it "can create a transaction with a three_d_secure_pass_thru" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :three_d_secure_pass_thru => {
            :eci_flag => "02",
            :cavv => "some_cavv",
            :xid => "some_xid",
            :three_d_secure_version => "1.0.2",
            :authentication_response => "Y",
            :directory_response => "Y",
            :cavv_algorithm => "2",
            :ds_transaction_id => "some_ds_id",
          }
        )

        result.success?.should == true
        result.transaction.status.should == Braintree::Transaction::Status::Authorized
      end

      it "returns an error for transaction with three_d_secure_pass_thru when processor settings do not support 3DS for card type" do
        result = Braintree::Transaction.create(
          :merchant_account_id => "heartland_ma",
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :three_d_secure_pass_thru => {
            :eci_flag => "02",
            :cavv => "some_cavv",
            :xid => "some_xid",
            :three_d_secure_version => "1.0.2",
            :authentication_response => "Y",
            :directory_response => "Y",
            :cavv_algorithm => "2",
            :ds_transaction_id => "some_ds_id",
          }
        )
        result.success?.should == false
        result.errors.for(:transaction).on(:merchant_account_id)[0].code.should == Braintree::ErrorCodes::Transaction::ThreeDSecureMerchantAccountDoesNotSupportCardType
      end

      it "returns an error for transaction when the three_d_secure_pass_thru eci_flag is missing" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :three_d_secure_pass_thru => {
            :eci_flag => "",
            :cavv => "some_cavv",
            :xid => "some_xid",
          }
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:three_d_secure_pass_thru).on(:eci_flag)[0].code.should == Braintree::ErrorCodes::Transaction::ThreeDSecureEciFlagIsRequired
      end

      it "returns an error for transaction when the three_d_secure_pass_thru cavv or xid is missing" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :three_d_secure_pass_thru => {
            :eci_flag => "05",
            :cavv => "",
            :xid => "",
            :three_d_secure_version => "1.0.2",
            :authentication_response => "Y",
            :directory_response => "Y",
            :cavv_algorithm => "2",
            :ds_transaction_id => "some_ds_id",
          }
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:three_d_secure_pass_thru).on(:cavv)[0].code.should == Braintree::ErrorCodes::Transaction::ThreeDSecureCavvIsRequired
      end

      it "returns an error for transaction when the three_d_secure_pass_thru eci_flag is invalid" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :three_d_secure_pass_thru => {
            :eci_flag => "bad_eci_flag",
            :cavv => "some_cavv",
            :xid => "some_xid",
            :three_d_secure_version => "1.0.2",
            :authentication_response => "Y",
            :directory_response => "Y",
            :cavv_algorithm => "2",
            :ds_transaction_id => "some_ds_id",
          }
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:three_d_secure_pass_thru).on(:eci_flag)[0].code.should == Braintree::ErrorCodes::Transaction::ThreeDSecureEciFlagIsInvalid
      end

      it "returns an error for transaction when the three_d_secure_pass_thru three_d_secure_version is invalid" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :three_d_secure_pass_thru => {
            :eci_flag => "02",
            :cavv => "some_cavv",
            :xid => "some_xid",
            :three_d_secure_version => "invalid",
            :authentication_response => "Y",
            :directory_response => "Y",
            :cavv_algorithm => "2",
            :ds_transaction_id => "some_ds_id",
          }
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:three_d_secure_pass_thru).on(:three_d_secure_version)[0].code.should == Braintree::ErrorCodes::Transaction::ThreeDSecureThreeDSecureVersionIsInvalid
      end

      it "returns an error for transaction when the three_d_secure_pass_thru authentication_response is invalid" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :merchant_account_id => SpecHelper:: AdyenMerchantAccountId,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :three_d_secure_pass_thru => {
            :eci_flag => "02",
            :cavv => "some_cavv",
            :xid => "some_xid",
            :three_d_secure_version => "1.0.2",
            :authentication_response => "asdf",
            :directory_response => "Y",
            :cavv_algorithm => "2",
            :ds_transaction_id => "some_ds_id",
          }
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:three_d_secure_pass_thru).on(:authentication_response)[0].code.should == Braintree::ErrorCodes::Transaction::ThreeDSecureAuthenticationResponseIsInvalid
      end

      it "returns an error for transaction when the three_d_secure_pass_thru directory_response is invalid" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :merchant_account_id => SpecHelper:: AdyenMerchantAccountId,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :three_d_secure_pass_thru => {
            :eci_flag => "02",
            :cavv => "some_cavv",
            :xid => "some_xid",
            :three_d_secure_version => "1.0.2",
            :authentication_response => "Y",
            :directory_response => "abc",
            :cavv_algorithm => "2",
            :ds_transaction_id => "some_ds_id",
          }
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:three_d_secure_pass_thru).on(:directory_response)[0].code.should == Braintree::ErrorCodes::Transaction::ThreeDSecureDirectoryResponseIsInvalid
      end

      it "returns an error for transaction when the three_d_secure_pass_thru cavv_algorithm is invalid" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :merchant_account_id => SpecHelper:: AdyenMerchantAccountId,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "12/12",
          },
          :three_d_secure_pass_thru => {
            :eci_flag => "02",
            :cavv => "some_cavv",
            :xid => "some_xid",
            :three_d_secure_version => "1.0.2",
            :authentication_response => "Y",
            :directory_response => "Y",
            :cavv_algorithm => "bad_alg",
            :ds_transaction_id => "some_ds_id",
          }
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:three_d_secure_pass_thru).on(:cavv_algorithm)[0].code.should == Braintree::ErrorCodes::Transaction::ThreeDSecureCavvAlgorithmIsInvalid
      end
    end

    context "paypal" do
      context "using a vaulted paypal account payment_method_token" do
        it "can create a transaction" do
          payment_method_result = Braintree::PaymentMethod.create(
            :customer_id => Braintree::Customer.create.customer.id,
            :payment_method_nonce => Braintree::Test::Nonce::PayPalFuturePayment
          )
          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :payment_method_token => payment_method_result.payment_method.token
          )

          result.should be_success
          result.transaction.payment_instrument_type.should == Braintree::PaymentInstrumentType::PayPalAccount
          result.transaction.paypal_details.should_not be_nil
          result.transaction.paypal_details.debug_id.should_not be_nil
        end
      end

      context "future" do
        it "can create a paypal transaction with a nonce without vaulting" do
          payment_method_token = rand(36**3).to_s(36)
          nonce = nonce_for_paypal_account(
            :consent_code => "PAYPAL_CONSENT_CODE",
            :token => payment_method_token
          )

          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :payment_method_nonce => nonce
          )

          result.should be_success
          result.transaction.paypal_details.should_not be_nil
          result.transaction.paypal_details.debug_id.should_not be_nil

          expect do
            Braintree::PaymentMethod.find(payment_method_token)
          end.to raise_error(Braintree::NotFoundError, "payment method with token \"#{payment_method_token}\" not found")
        end

        it "can create a paypal transaction and vault a paypal account" do
          payment_method_token = rand(36**3).to_s(36)
          nonce = nonce_for_paypal_account(
            :consent_code => "PAYPAL_CONSENT_CODE",
            :token => payment_method_token
          )

          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :payment_method_nonce => nonce,
            :options => {:store_in_vault => true}
          )

          result.success?.should == true
          result.transaction.paypal_details.should_not be_nil
          result.transaction.paypal_details.debug_id.should_not be_nil

          found_paypal_account = Braintree::PaymentMethod.find(payment_method_token)
          found_paypal_account.should be_a(Braintree::PayPalAccount)
          found_paypal_account.token.should == payment_method_token
        end
      end

      context "local payments" do
        it "can create a local payment transaction with a nonce" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :payment_method_nonce => Braintree::Test::Nonce::LocalPayment
          )

          result.should be_success
          result.transaction.local_payment_details.should_not be_nil
          result.transaction.local_payment_details.funding_source.should_not be_nil
          result.transaction.local_payment_details.payment_id.should_not be_nil
          result.transaction.local_payment_details.capture_id.should_not be_nil
          result.transaction.local_payment_details.transaction_fee_amount.should_not be_nil
          result.transaction.local_payment_details.transaction_fee_currency_iso_code.should_not be_nil
        end
      end

      context "onetime" do
        it "can create a paypal transaction with a nonce" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :payment_method_nonce => Braintree::Test::Nonce::PayPalOneTimePayment
          )

          result.should be_success
          result.transaction.paypal_details.should_not be_nil
          result.transaction.paypal_details.debug_id.should_not be_nil
        end

        it "can create a paypal transaction and does not vault even if asked to" do
          payment_method_token = rand(36**3).to_s(36)
          nonce = nonce_for_paypal_account(
            :access_token => "PAYPAL_ACCESS_TOKEN",
            :token => payment_method_token
          )

          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :payment_method_nonce => nonce,
            :options => {:store_in_vault => true}
          )

          result.success?.should == true
          result.transaction.paypal_details.should_not be_nil
          result.transaction.paypal_details.debug_id.should_not be_nil

          expect do
            Braintree::PaymentMethod.find(payment_method_token)
          end.to raise_error(Braintree::NotFoundError, "payment method with token \"#{payment_method_token}\" not found")
        end
      end

      context "submit" do
        it "submits for settlement if instructed to do so" do
          result = Braintree::Transaction.sale(
            :amount => "100",
            :payment_method_nonce => Braintree::Test::Nonce::PayPalOneTimePayment,
            :options => {
              :submit_for_settlement => true
            }
          )
          result.success?.should == true
          result.transaction.status.should == Braintree::Transaction::Status::Settling
        end
      end

      context "void" do
        it "successfully voids a paypal transaction that's been authorized" do
          sale_transaction = Braintree::Transaction.sale!(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :payment_method_nonce => Braintree::Test::Nonce::PayPalOneTimePayment
          )

          void_transaction = Braintree::Transaction.void!(sale_transaction.id)
          void_transaction.should == sale_transaction
          void_transaction.status.should == Braintree::Transaction::Status::Voided
        end

        it "fails to void a paypal transaction that's been declined" do
          sale_transaction = Braintree::Transaction.sale(
            :amount => Braintree::Test::TransactionAmounts::Decline,
            :payment_method_nonce => Braintree::Test::Nonce::PayPalOneTimePayment
          ).transaction

          expect do
            Braintree::Transaction.void!(sale_transaction.id)
          end.to raise_error(Braintree::ValidationsFailed)
        end
      end

      describe "refund" do
        context "partial refunds" do
          it "allows partial refunds" do
            transaction = create_paypal_transaction_for_refund

            result = Braintree::Transaction.refund(transaction.id, transaction.amount / 2)
            result.should be_success
            result.transaction.type.should == "credit"
          end

          it "allows multiple partial refunds" do
            transaction = create_paypal_transaction_for_refund

            transaction_1 = Braintree::Transaction.refund(transaction.id, transaction.amount / 2).transaction
            transaction_2 = Braintree::Transaction.refund(transaction.id, transaction.amount / 2).transaction

            transaction = Braintree::Transaction.find(transaction.id)
            transaction.refund_ids.sort.should == [transaction_1.id, transaction_2.id].sort
          end

          it "allows partial refunds passed in an options hash" do
            transaction = create_paypal_transaction_for_refund

            transaction_1 = Braintree::Transaction.refund(transaction.id, :amount => transaction.amount / 2).transaction
            transaction_2 = Braintree::Transaction.refund(transaction.id, :amount => transaction.amount / 2).transaction

            transaction = Braintree::Transaction.find(transaction.id)
            transaction.refund_ids.sort.should == [transaction_1.id, transaction_2.id].sort
          end
        end

        it "returns a successful result if successful" do
          transaction = create_paypal_transaction_for_refund

          result = Braintree::Transaction.refund(transaction.id)

          result.success?.should == true
          result.transaction.type.should == "credit"
        end

        it "allows an order_id to be passed for the refund" do
          transaction = create_paypal_transaction_for_refund

          result = Braintree::Transaction.refund(transaction.id, :order_id => "123458798123")

          result.success?.should == true
          result.transaction.type.should == "credit"
          result.transaction.order_id.should == "123458798123"
        end

        it "allows amount and order_id to be passed for the refund" do
          transaction = create_paypal_transaction_for_refund

          result = Braintree::Transaction.refund(transaction.id, :amount => transaction.amount/2, :order_id => "123458798123")

          result.success?.should == true
          result.transaction.type.should == "credit"
          result.transaction.order_id.should == "123458798123"
          result.transaction.amount.should == transaction.amount/2
        end

        it "does not allow arbitrary options to be passed" do
          transaction = create_paypal_transaction_for_refund

          expect {
            Braintree::Transaction.refund(transaction.id, :blah => "123458798123")
          }.to raise_error(ArgumentError)
        end

        it "assigns the refund_id on the original transaction" do
          transaction = create_paypal_transaction_for_refund
          refund_transaction = Braintree::Transaction.refund(transaction.id).transaction
          transaction = Braintree::Transaction.find(transaction.id)

          transaction.refund_id.should == refund_transaction.id
        end

        it "assigns the refunded_transaction_id to the original transaction" do
          transaction = create_paypal_transaction_for_refund
          refund_transaction = Braintree::Transaction.refund(transaction.id).transaction

          refund_transaction.refunded_transaction_id.should == transaction.id
        end

        it "returns an error result if unsettled" do
          transaction = Braintree::Transaction.sale!(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :payment_method_nonce => Braintree::Test::Nonce::PayPalOneTimePayment
          )
          result = Braintree::Transaction.refund(transaction.id)
          result.success?.should == false
          result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::CannotRefundUnlessSettled
        end

        it "handles soft declined refund authorizations" do
          transaction = Braintree::Transaction.sale!(
            :amount => "9000.00",
            :payment_method_nonce => Braintree::Test::Nonce::Transactable,
            :options => {
              :submit_for_settlement => true
            }
          )
          config = Braintree::Configuration.instantiate
          response = config.http.put("#{config.base_merchant_path}/transactions/#{transaction.id}/settle")
          result = Braintree::Transaction.refund(transaction.id, :amount => "2046.00")
          result.success?.should == false
          result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::RefundAuthSoftDeclined
        end

        it "handles hard declined refund authorizations" do
          transaction = Braintree::Transaction.sale!(
            :amount => "9000.00",
            :payment_method_nonce => Braintree::Test::Nonce::Transactable,
            :options => {
              :submit_for_settlement => true
            }
          )
          config = Braintree::Configuration.instantiate
          response = config.http.put("#{config.base_merchant_path}/transactions/#{transaction.id}/settle")
          result = Braintree::Transaction.refund(transaction.id, :amount => "2009.00")
          result.success?.should == false
          result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::RefundAuthHardDeclined
        end
      end

      context "handling errors" do
        it "handles bad unvalidated nonces" do
          nonce = nonce_for_paypal_account(
            :access_token => "PAYPAL_ACCESS_TOKEN",
            :consent_code => "PAYPAL_CONSENT_CODE"
          )

          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :payment_method_nonce => nonce
          )

          result.should_not be_success
          result.errors.for(:transaction).for(:paypal_account).first.code.should == "82903"
        end

        it "handles non-existent nonces" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :payment_method_nonce => "NON_EXISTENT_NONCE"
          )

          result.should_not be_success
          result.errors.for(:transaction).first.code.should == "91565"
        end
      end
    end

    context "line items" do
      it "allows creation with empty line items and returns none" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [],
        )
        result.success?.should == true
        result.transaction.line_items.should == []
      end

      it "allows creation with single line item with minimal fields and returns it" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "45.15",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.0232",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :total_amount => "45.15",
            },
          ],
        )
        result.success?.should == true
        result.transaction.line_items.length.should == 1
        line_item = result.transaction.line_items[0]
        line_item.quantity.should == BigDecimal("1.0232")
        line_item.name.should == "Name #1"
        line_item.kind.should == "debit"
        line_item.unit_amount.should == BigDecimal("45.1232")
        line_item.total_amount.should == BigDecimal("45.15")
      end

      it "allows creation with single line item with zero amount fields and returns it" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "45.15",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.0232",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :total_amount => "45.15",
              :unit_tax_amount => "0",
              :discount_amount => "0",
              :tax_amount => "0",
            },
          ],
        )
        result.success?.should == true
        result.transaction.line_items.length.should == 1
        line_item = result.transaction.line_items[0]
        line_item.quantity.should == BigDecimal("1.0232")
        line_item.name.should == "Name #1"
        line_item.kind.should == "debit"
        line_item.unit_amount.should == BigDecimal("45.1232")
        line_item.total_amount.should == BigDecimal("45.15")
        line_item.unit_tax_amount.should == BigDecimal("0")
        line_item.discount_amount.should == BigDecimal("0")
        line_item.tax_amount.should == BigDecimal("0")
      end

      it "allows creation with single line item and returns it" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "45.15",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.0232",
              :name => "Name #1",
              :description => "Description #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_tax_amount => "1.23",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :tax_amount => "4.50",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
              :url => "https://example.com/products/23434",
            },
          ],
        )
        result.success?.should == true
        result.transaction.line_items.length.should == 1
        line_item = result.transaction.line_items[0]
        line_item.quantity.should == BigDecimal("1.0232")
        line_item.name.should == "Name #1"
        line_item.description.should == "Description #1"
        line_item.kind.should == "debit"
        line_item.unit_amount.should == BigDecimal("45.1232")
        line_item.unit_tax_amount.should == BigDecimal("1.23")
        line_item.unit_of_measure.should == "gallon"
        line_item.discount_amount.should == BigDecimal("1.02")
        line_item.tax_amount.should == BigDecimal("4.50")
        line_item.total_amount.should == BigDecimal("45.15")
        line_item.product_code.should == "23434"
        line_item.commodity_code.should == "9SAASSD8724"
        line_item.url.should == "https://example.com/products/23434"
      end

      it "allows creation with multiple line items and returns them" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.0232",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :tax_amount => "4.50",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "2.02",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "5",
              :unit_of_measure => "gallon",
              :tax_amount => "1.50",
              :total_amount => "10.1",
            },
          ],
        )
        result.success?.should == true
        result.transaction.line_items.length.should == 2
        line_item_1 = result.transaction.line_items.find { |line_item| line_item.name == "Name #1" }
        line_item_1.quantity.should == BigDecimal("1.0232")
        line_item_1.name.should == "Name #1"
        line_item_1.kind.should == "debit"
        line_item_1.unit_amount.should == BigDecimal("45.1232")
        line_item_1.unit_of_measure.should == "gallon"
        line_item_1.discount_amount.should == BigDecimal("1.02")
        line_item_1.tax_amount.should == BigDecimal("4.50")
        line_item_1.total_amount.should == BigDecimal("45.15")
        line_item_1.product_code.should == "23434"
        line_item_1.commodity_code.should == "9SAASSD8724"
        line_item_2 = result.transaction.line_items.find { |line_item| line_item.name == "Name #2" }
        line_item_2.quantity.should == BigDecimal("2.02")
        line_item_2.name.should == "Name #2"
        line_item_2.kind.should == "credit"
        line_item_2.unit_amount.should == BigDecimal("5")
        line_item_2.unit_of_measure.should == "gallon"
        line_item_2.total_amount.should == BigDecimal("10.1")
        line_item_2.tax_amount.should == BigDecimal("1.50")
        line_item_2.discount_amount.should == nil
        line_item_2.product_code.should == nil
        line_item_2.commodity_code.should == nil
      end

      it "handles validation error commodity code is too long" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "1234567890123",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:commodity_code)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::CommodityCodeIsTooLong
      end

      it "handles validation error description is too long" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :description => "X" * 128,
              :kind => "credit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:description)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::DescriptionIsTooLong
      end

      it "handles validation error discount amount format is invalid" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "$1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:discount_amount)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::DiscountAmountFormatIsInvalid
      end

      it "handles validation error discount amount is too large" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "2147483648",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:discount_amount)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::DiscountAmountIsTooLarge
      end

      it "handles validation error discount amount cannot be negative" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "-2",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:discount_amount)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::DiscountAmountCannotBeNegative
      end

      it "handles validation error tax amount format is invalid" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :tax_amount => "$1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_0).on(:tax_amount)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::TaxAmountFormatIsInvalid
      end

      it "handles validation error tax amount is too large" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :tax_amount => "2147483648",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_0).on(:tax_amount)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::TaxAmountIsTooLarge
      end

      it "handles validation error tax amount cannot be negative" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :tax_amount => "-2",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_0).on(:tax_amount)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::TaxAmountCannotBeNegative
      end

      it "handles validation error kind is invalid" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "sale",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:kind)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::KindIsInvalid
      end

      it "handles validation error kind is required" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:kind)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::KindIsRequired
      end

      it "handles validation error name is required" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:name)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::NameIsRequired
      end

      it "handles validation error name is too long" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "X"*36,
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:name)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::NameIsTooLong
      end

      it "handles validation error product code is too long" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "1234567890123",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:product_code)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::ProductCodeIsTooLong
      end

      it "handles validation error quantity format is invalid" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1,2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:quantity)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::QuantityFormatIsInvalid
      end

      it "handles validation error quantity is required" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:quantity)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::QuantityIsRequired
      end

      it "handles validation error quantity is too large" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "2147483648",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:quantity)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::QuantityIsTooLarge
      end

      it "handles validation error total amount format is invalid" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "$45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:total_amount)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::TotalAmountFormatIsInvalid
      end

      it "handles validation error total amount is required" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:total_amount)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::TotalAmountIsRequired
      end

      it "handles validation error total amount is too large" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "2147483648",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:total_amount)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::TotalAmountIsTooLarge
      end

      it "handles validation error total amount must be greater than zero" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "-2",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:total_amount)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::TotalAmountMustBeGreaterThanZero
      end

      it "handles validation error unit amount format is invalid" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "45.01232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:unit_amount)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::UnitAmountFormatIsInvalid
      end

      it "handles validation error unit amount is required" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:unit_amount)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::UnitAmountIsRequired
      end

      it "handles validation error unit amount is too large" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "2147483648",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:unit_amount)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::UnitAmountIsTooLarge
      end

      it "handles validation error unit amount must be greater than zero" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "-2",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:unit_amount)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::UnitAmountMustBeGreaterThanZero
      end

      it "handles validation error unit of measure is too long" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "45.1232",
              :unit_of_measure => "1234567890123",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:unit_of_measure)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::UnitOfMeasureIsTooLong
      end

      it "handles validation error unit tax amount format is invalid" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_tax_amount => "2.34",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "45.0122",
              :unit_tax_amount => "2.012",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:unit_tax_amount)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::UnitTaxAmountFormatIsInvalid
      end

      it "handles validation error unit tax amount is too large" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_tax_amount => "1.23",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "45.0122",
              :unit_tax_amount => "2147483648",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:unit_tax_amount)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::UnitTaxAmountIsTooLarge
      end

      it "handles validation error unit tax amount cannot be negative" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => [
            {
              :quantity => "1.2322",
              :name => "Name #1",
              :kind => "debit",
              :unit_amount => "45.1232",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
            {
              :quantity => "1.2322",
              :name => "Name #2",
              :kind => "credit",
              :unit_amount => "45.0122",
              :unit_tax_amount => "-1.23",
              :unit_of_measure => "gallon",
              :discount_amount => "1.02",
              :total_amount => "45.15",
              :product_code => "23434",
              :commodity_code => "9SAASSD8724",
            },
          ],
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:line_items).for(:index_1).on(:unit_tax_amount)[0].code.should == Braintree::ErrorCodes::TransactionLineItem::UnitTaxAmountCannotBeNegative
      end

      it "handles validation errors on line items structure" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => {
            :quantity => "2.02",
            :name => "Name #2",
            :kind => "credit",
            :unit_amount => "5",
            :unit_of_measure => "gallon",
            :total_amount => "10.1",
          },
        )
        result.success?.should == false
        result.errors.for(:transaction).on(:line_items)[0].code.should == Braintree::ErrorCodes::Transaction::LineItemsExpected
      end

      it "handles invalid arguments on line items structure" do
        expect do
          Braintree::Transaction.create(
            :type => "sale",
            :amount => "35.05",
            :payment_method_nonce => Braintree::Test::Nonce::Transactable,
            :line_items => [
              {
                :quantity => "2.02",
                :name => "Name #1",
                :kind => "credit",
                :unit_amount => "5",
                :unit_of_measure => "gallon",
                :total_amount => "10.1",
              },
              ['Name #2'],
              {
                :quantity => "2.02",
                :name => "Name #3",
                :kind => "credit",
                :unit_amount => "5",
                :unit_of_measure => "gallon",
                :total_amount => "10.1",
              },
            ],
          )
        end.to raise_error(ArgumentError)
      end

      it "handles validation errors on too many line items" do
        line_items = 250.times.map do |i|
          {
            :quantity => "2.02",
            :name => "Line item ##{i}",
            :kind => "credit",
            :unit_amount => "5",
            :unit_of_measure => "gallon",
            :total_amount => "10.1",
          }
        end
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => "35.05",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :line_items => line_items,
        )
        result.success?.should == false
        result.errors.for(:transaction).on(:line_items)[0].code.should == Braintree::ErrorCodes::Transaction::TooManyLineItems
      end
    end

    context "level 3 summary data" do
      it "accepts level 3 summary data" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :amount => "10.00",
          :shipping_amount => "1.00",
          :discount_amount => "2.00",
          :ships_from_postal_code => "12345",
        )

        result.success?.should == true
        result.transaction.shipping_amount.should == "1.00"
        result.transaction.discount_amount.should == "2.00"
        result.transaction.ships_from_postal_code.should == "12345"
      end

      it "handles validation errors on summary data" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :amount => "10.00",
          :shipping_amount => "1a00",
          :discount_amount => "-2.00",
          :ships_from_postal_code => "1$345",
        )

        result.success?.should == false
        result.errors.for(:transaction).on(:shipping_amount)[0].code.should == Braintree::ErrorCodes::Transaction::ShippingAmountFormatIsInvalid
        result.errors.for(:transaction).on(:discount_amount)[0].code.should == Braintree::ErrorCodes::Transaction::DiscountAmountCannotBeNegative
        result.errors.for(:transaction).on(:ships_from_postal_code)[0].code.should == Braintree::ErrorCodes::Transaction::ShipsFromPostalCodeInvalidCharacters
      end

      it "handles validation error discount amount format is invalid" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :amount => "10.00",
          :discount_amount => "2.001",
        )

        result.success?.should == false
        result.errors.for(:transaction).on(:discount_amount)[0].code.should == Braintree::ErrorCodes::Transaction::DiscountAmountFormatIsInvalid
      end

      it "handles validation error discount amount cannot be negative" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :amount => "10.00",
          :discount_amount => "-2",
        )

        result.success?.should == false
        result.errors.for(:transaction).on(:discount_amount)[0].code.should == Braintree::ErrorCodes::Transaction::DiscountAmountCannotBeNegative
      end

      it "handles validation error discount amount is too large" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :amount => "10.00",
          :discount_amount => "2147483648",
        )

        result.success?.should == false
        result.errors.for(:transaction).on(:discount_amount)[0].code.should == Braintree::ErrorCodes::Transaction::DiscountAmountIsTooLarge
      end

      it "handles validation error shipping amount format is invalid" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :amount => "10.00",
          :shipping_amount => "2.001",
        )

        result.success?.should == false
        result.errors.for(:transaction).on(:shipping_amount)[0].code.should == Braintree::ErrorCodes::Transaction::ShippingAmountFormatIsInvalid
      end

      it "handles validation error shipping amount cannot be negative" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :amount => "10.00",
          :shipping_amount => "-2",
        )

        result.success?.should == false
        result.errors.for(:transaction).on(:shipping_amount)[0].code.should == Braintree::ErrorCodes::Transaction::ShippingAmountCannotBeNegative
      end

      it "handles validation error shipping amount is too large" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :amount => "10.00",
          :shipping_amount => "2147483648",
        )

        result.success?.should == false
        result.errors.for(:transaction).on(:shipping_amount)[0].code.should == Braintree::ErrorCodes::Transaction::ShippingAmountIsTooLarge
      end

      it "handles validation error ships from postal code is too long" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :amount => "10.00",
          :ships_from_postal_code => "1234567890",
        )

        result.success?.should == false
        result.errors.for(:transaction).on(:ships_from_postal_code)[0].code.should == Braintree::ErrorCodes::Transaction::ShipsFromPostalCodeIsTooLong
      end

      it "handles validation error ships from postal code invalid characters" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :payment_method_nonce => Braintree::Test::Nonce::Transactable,
          :amount => "10.00",
          :ships_from_postal_code => "12345%78",
        )

        result.success?.should == false
        result.errors.for(:transaction).on(:ships_from_postal_code)[0].code.should == Braintree::ErrorCodes::Transaction::ShipsFromPostalCodeInvalidCharacters
      end
    end

    context "network_transaction_id" do
      it "receives network_transaction_id for visa transaction" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          },
          :amount => "10.00",
        )
        result.success?.should == true
        result.transaction.network_transaction_id.should_not be_nil
      end
    end

    context "external vault" do
      it "returns a validation error if used with an unsupported instrument type" do
        customer = Braintree::Customer.create!
        result = Braintree::PaymentMethod.create(
          :payment_method_nonce => Braintree::Test::Nonce::PayPalFuturePayment,
          :customer_id => customer.id
        )
        payment_method_token = result.payment_method.token

        result = Braintree::Transaction.create(
          :type => "sale",
          :customer_id => customer.id,
          :payment_method_token => payment_method_token,
          :external_vault => {
            :status => Braintree::Transaction::ExternalVault::Status::WillVault,
          },
          :amount => "10.00",
        )
        result.success?.should == false
        result.errors.for(:transaction)[0].code.should == Braintree::ErrorCodes::Transaction::PaymentInstrumentWithExternalVaultIsInvalid
      end

      it "reject invalid status" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::MasterCard,
            :expiration_date => "05/2009"
          },
          :external_vault => {
            :status => "not_valid",
          },
          :amount => "10.00",
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:external_vault).on(:status)[0].code.should == Braintree::ErrorCodes::Transaction::ExternalVault::StatusIsInvalid
      end

      context "Visa/Mastercard/Discover" do
        it "accepts status" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "05/2009"
            },
            :external_vault => {
              :status => Braintree::Transaction::ExternalVault::Status::WillVault,
            },
            :amount => "10.00",
          )
          result.success?.should == true
          result.transaction.network_transaction_id.should_not be_nil
        end

        it "accepts previous_network_transaction_id" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::MasterCard,
              :expiration_date => "05/2009"
            },
            :external_vault => {
              :status => Braintree::Transaction::ExternalVault::Status::Vaulted,
              :previous_network_transaction_id => "123456789012345",
            },
            :amount => "10.00",
          )
          result.success?.should == true
          result.transaction.network_transaction_id.should_not be_nil
        end

        it "rejects non-vaulted status with previous_network_transaction_id" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Discover,
              :expiration_date => "05/2009"
            },
            :external_vault => {
              :status => Braintree::Transaction::ExternalVault::Status::WillVault,
              :previous_network_transaction_id => "123456789012345",
            },
            :amount => "10.00",
          )
          result.success?.should == false
          result.errors.for(:transaction).for(:external_vault).on(:status)[0].code.should == Braintree::ErrorCodes::Transaction::ExternalVault::StatusWithPreviousNetworkTransactionIdIsInvalid
        end
      end

      context "Non-(Visa/Mastercard/Discover) card types" do
        it "accepts status" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::AmExes[0],
              :expiration_date => "05/2009"
            },
            :external_vault => {
              :status => Braintree::Transaction::ExternalVault::Status::WillVault,
            },
            :amount => "10.00",
          )
          result.success?.should == true
          result.transaction.network_transaction_id.should be_nil
        end

        it "accepts blank previous_network_transaction_id" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::AmExes[0],
              :expiration_date => "05/2009"
            },
            :external_vault => {
              :status => Braintree::Transaction::ExternalVault::Status::Vaulted,
              :previous_network_transaction_id => "",
            },
            :amount => "10.00",
          )
          result.success?.should == true
          result.transaction.network_transaction_id.should be_nil
        end

        it "rejects previous_network_transaction_id" do
          result = Braintree::Transaction.create(
            :type => "sale",
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::AmExes[0],
              :expiration_date => "05/2009"
            },
            :external_vault => {
              :status => Braintree::Transaction::ExternalVault::Status::Vaulted,
              :previous_network_transaction_id => "123456789012345",
            },
            :amount => "10.00",
          )
          result.success?.should == false
          result.errors.for(:transaction).for(:external_vault).on(:previous_network_transaction_id)[0].code.should == Braintree::ErrorCodes::Transaction::ExternalVault::CardTypeIsInvalid
        end
      end

    end

    context "account_type" do
      it "creates a Hiper transaction with account type credit" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :merchant_account_id => SpecHelper::HiperBRLMerchantAccountId,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Hiper,
            :expiration_date => "05/2009"
          },
          :amount => "10.00",
          :options => {
            :credit_card => {
              :account_type => "credit",
            }
          }
        )
        result.success?.should == true
        result.transaction.credit_card_details.account_type.should == "credit"
      end

      it "creates a Hipercard transaction with account_type credit" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :merchant_account_id => SpecHelper::HiperBRLMerchantAccountId,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Hipercard,
            :expiration_date => "05/2009"
          },
          :amount => "10.00",
          :options => {
            :credit_card => {
              :account_type => "credit",
            }
          }
        )
        result.success?.should == true
        result.transaction.credit_card_details.account_type.should == "credit"
      end

      it "creates a Hiper transaction with account_type debit" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :merchant_account_id => SpecHelper::HiperBRLMerchantAccountId,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Hiper,
            :expiration_date => "05/2009"
          },
          :amount => "10.00",
          :options => {
            :credit_card => {
              :account_type => "debit",
            },
            :submit_for_settlement => true,
          }
        )
        result.success?.should == true
        result.transaction.credit_card_details.account_type.should == "debit"
      end

      it "does not allow auths with account_type debit" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :merchant_account_id => SpecHelper::HiperBRLMerchantAccountId,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Hiper,
            :expiration_date => "05/2009"
          },
          :amount => "10.00",
          :options => {
            :credit_card => {
              :account_type => "debit",
            },
          }
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:options).for(:credit_card).on(:account_type)[0].code.should == Braintree::ErrorCodes::Transaction::Options::CreditCard::AccountTypeDebitDoesNotSupportAuths
      end

      it "does not allow invalid account_type" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :merchant_account_id => SpecHelper::HiperBRLMerchantAccountId,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Hiper,
            :expiration_date => "05/2009"
          },
          :amount => "10.00",
          :options => {
            :credit_card => {
              :account_type => "ach",
            },
          }
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:options).for(:credit_card).on(:account_type)[0].code.should == Braintree::ErrorCodes::Transaction::Options::CreditCard::AccountTypeIsInvalid
      end

      it "does not allow account_type not supported by merchant" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          },
          :amount => "10.00",
          :options => {
            :credit_card => {
              :account_type => "credit",
            },
          }
        )
        result.success?.should == false
        result.errors.for(:transaction).for(:options).for(:credit_card).on(:account_type)[0].code.should == Braintree::ErrorCodes::Transaction::Options::CreditCard::AccountTypeNotSupported
      end
    end
  end

  describe "self.create!" do
    it "returns the transaction if valid" do
      transaction = Braintree::Transaction.create!(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      transaction.id.should =~ /^\w{6,}$/
      transaction.type.should == "sale"
      transaction.amount.should == BigDecimal(Braintree::Test::TransactionAmounts::Authorize)
      transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      transaction.credit_card_details.expiration_date.should == "05/2009"
    end

    it "raises a validationsfailed if invalid" do
      expect do
        Braintree::Transaction.create!(
          :type => "sale",
          :amount => nil,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          }
        )
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "self.refund" do
    context "partial refunds" do
      it "allows partial refunds" do
        transaction = create_transaction_to_refund
        result = Braintree::Transaction.refund(transaction.id, transaction.amount / 2)
        result.success?.should == true
        result.transaction.type.should == "credit"
      end

      it "allows multiple partial refunds" do
        transaction = create_transaction_to_refund
        transaction_1 = Braintree::Transaction.refund(transaction.id, transaction.amount / 2).transaction
        transaction_2 = Braintree::Transaction.refund(transaction.id, transaction.amount / 2).transaction

        transaction = Braintree::Transaction.find(transaction.id)
        transaction.refund_ids.sort.should == [transaction_1.id, transaction_2.id].sort
      end
    end

    it "returns a successful result if successful" do
      transaction = create_transaction_to_refund
      transaction.status.should == Braintree::Transaction::Status::Settled
      result = Braintree::Transaction.refund(transaction.id)
      result.success?.should == true
      result.transaction.type.should == "credit"
    end

    it "assigns the refund_id on the original transaction" do
      transaction = create_transaction_to_refund
      refund_transaction = Braintree::Transaction.refund(transaction.id).transaction
      transaction = Braintree::Transaction.find(transaction.id)

      transaction.refund_id.should == refund_transaction.id
    end

    it "assigns the refunded_transaction_id to the original transaction" do
      transaction = create_transaction_to_refund
      refund_transaction = Braintree::Transaction.refund(transaction.id).transaction

      refund_transaction.refunded_transaction_id.should == transaction.id
    end

    it "returns an error if already refunded" do
      transaction = create_transaction_to_refund
      result = Braintree::Transaction.refund(transaction.id)
      result.success?.should == true
      result = Braintree::Transaction.refund(transaction.id)
      result.success?.should == false
      result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::HasAlreadyBeenRefunded
    end

    it "returns an error result if unsettled" do
      transaction = Braintree::Transaction.create!(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      result = Braintree::Transaction.refund(transaction.id)
      result.success?.should == false
      result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::CannotRefundUnlessSettled
    end
  end

  describe "self.refund!" do
    it "returns the refund if valid refund" do
      transaction = create_transaction_to_refund

      refund_transaction = Braintree::Transaction.refund!(transaction.id)

      refund_transaction.refunded_transaction_id.should == transaction.id
      refund_transaction.type.should == "credit"
      transaction.amount.should == refund_transaction.amount
    end

    it "raises a ValidationsFailed if invalid" do
      transaction = create_transaction_to_refund
      invalid_refund_amount = transaction.amount + 1
      invalid_refund_amount.should be > transaction.amount

      expect do
        Braintree::Transaction.refund!(transaction.id,invalid_refund_amount)
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "self.sale" do
    it "returns a successful result with type=sale if successful" do
      result = Braintree::Transaction.sale(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      result.success?.should == true
      result.transaction.id.should =~ /^\w{6,}$/
      result.transaction.type.should == "sale"
      result.transaction.amount.should == BigDecimal(Braintree::Test::TransactionAmounts::Authorize)
      result.transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      result.transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      result.transaction.credit_card_details.expiration_date.should == "05/2009"
    end

    it "works when given all attributes" do
      result = Braintree::Transaction.sale(
        :amount => "100.00",
        :order_id => "123",
        :product_sku => "productsku01",
        :channel => "MyShoppingCartProvider",
        :credit_card => {
          :cardholder_name => "The Cardholder",
          :number => "5105105105105100",
          :expiration_date => "05/2011",
          :cvv => "123"
        },
        :customer => {
          :first_name => "Dan",
          :last_name => "Smith",
          :company => "Braintree",
          :email => "dan@example.com",
          :phone => "419-555-1234",
          :fax => "419-555-1235",
          :website => "http://braintreepayments.com"
        },
        :billing => {
          :first_name => "Carl",
          :last_name => "Jones",
          :company => "Braintree",
          :street_address => "123 E Main St",
          :extended_address => "Suite 403",
          :locality => "Chicago",
          :region => "IL",
          :phone_number => "122-555-1237",
          :postal_code => "60622",
          :country_name => "United States of America"
        },
        :shipping => {
          :first_name => "Andrew",
          :last_name => "Mason",
          :company => "Braintree",
          :street_address => "456 W Main St",
          :extended_address => "Apt 2F",
          :locality => "Bartlett",
          :region => "IL",
          :phone_number => "122-555-1236",
          :postal_code => "60103",
          :country_name => "United States of America",
          :shipping_method => Braintree::Transaction::AddressDetails::ShippingMethod::Electronic
        }
      )
      result.success?.should == true
      transaction = result.transaction
      transaction.id.should =~ /\A\w{6,}\z/
      transaction.type.should == "sale"
      transaction.status.should == Braintree::Transaction::Status::Authorized
      transaction.amount.should == BigDecimal("100.00")
      transaction.currency_iso_code.should == "USD"
      transaction.order_id.should == "123"
      transaction.channel.should == "MyShoppingCartProvider"
      transaction.processor_response_code.should == "1000"
      transaction.authorization_expires_at.between?(Time.now, Time.now + (60 * 60 * 24 * 60)).should == true
      transaction.created_at.between?(Time.now - 60, Time.now).should == true
      transaction.updated_at.between?(Time.now - 60, Time.now).should == true
      transaction.credit_card_details.bin.should == "510510"
      transaction.credit_card_details.cardholder_name.should == "The Cardholder"
      transaction.credit_card_details.last_4.should == "5100"
      transaction.credit_card_details.masked_number.should == "510510******5100"
      transaction.credit_card_details.card_type.should == "MasterCard"
      transaction.avs_error_response_code.should == nil
      transaction.avs_postal_code_response_code.should == "M"
      transaction.avs_street_address_response_code.should == "M"
      transaction.cvv_response_code.should == "M"
      transaction.customer_details.first_name.should == "Dan"
      transaction.customer_details.last_name.should == "Smith"
      transaction.customer_details.company.should == "Braintree"
      transaction.customer_details.email.should == "dan@example.com"
      transaction.customer_details.phone.should == "419-555-1234"
      transaction.customer_details.fax.should == "419-555-1235"
      transaction.customer_details.website.should == "http://braintreepayments.com"
      transaction.billing_details.first_name.should == "Carl"
      transaction.billing_details.last_name.should == "Jones"
      transaction.billing_details.company.should == "Braintree"
      transaction.billing_details.street_address.should == "123 E Main St"
      transaction.billing_details.extended_address.should == "Suite 403"
      transaction.billing_details.locality.should == "Chicago"
      transaction.billing_details.region.should == "IL"
      transaction.billing_details.postal_code.should == "60622"
      transaction.billing_details.country_name.should == "United States of America"
      transaction.billing_details.country_code_alpha2.should == "US"
      transaction.billing_details.country_code_alpha3.should == "USA"
      transaction.billing_details.country_code_numeric.should == "840"
      transaction.shipping_details.first_name.should == "Andrew"
      transaction.shipping_details.last_name.should == "Mason"
      transaction.shipping_details.company.should == "Braintree"
      transaction.shipping_details.street_address.should == "456 W Main St"
      transaction.shipping_details.extended_address.should == "Apt 2F"
      transaction.shipping_details.locality.should == "Bartlett"
      transaction.shipping_details.region.should == "IL"
      transaction.shipping_details.postal_code.should == "60103"
      transaction.shipping_details.country_name.should == "United States of America"
      transaction.shipping_details.country_code_alpha2.should == "US"
      transaction.shipping_details.country_code_alpha3.should == "USA"
      transaction.shipping_details.country_code_numeric.should == "840"
    end

    it "allows merchant account to be specified" do
      result = Braintree::Transaction.sale(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::NonDefaultMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      result.success?.should == true
      result.transaction.merchant_account_id.should == SpecHelper::NonDefaultMerchantAccountId
    end

    it "uses default merchant account when it is not specified" do
      result = Braintree::Transaction.sale(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      result.success?.should == true
      result.transaction.merchant_account_id.should == SpecHelper::DefaultMerchantAccountId
    end

    it "can store customer and credit card in the vault" do
      result = Braintree::Transaction.sale(
        :amount => "100",
        :customer => {
          :first_name => "Adam",
          :last_name => "Williams"
        },
        :credit_card => {
          :number => "5105105105105100",
          :expiration_date => "05/2012"
        },
        :options => {
          :store_in_vault => true
        }
      )
      result.success?.should == true
      transaction = result.transaction
      transaction.customer_details.id.should =~ /\A\d{6,}\z/
      transaction.vault_customer.id.should == transaction.customer_details.id
      transaction.credit_card_details.token.should =~ /\A\w{4,}\z/
      transaction.vault_credit_card.token.should == transaction.credit_card_details.token
    end

    it "associates a billing address with a credit card in the vault" do
      result = Braintree::Transaction.sale(
        :amount => "100",
        :customer => {
          :first_name => "Adam",
          :last_name => "Williams"
        },
        :credit_card => {
          :number => "5105105105105100",
          :expiration_date => "05/2012"
        },
        :billing => {
          :first_name => "Carl",
          :last_name => "Jones",
          :company => "Braintree",
          :street_address => "123 E Main St",
          :extended_address => "Suite 403",
          :locality => "Chicago",
          :region => "IL",
          :postal_code => "60622",
          :country_name => "United States of America"
        },
        :options => {
          :store_in_vault => true,
          :add_billing_address_to_payment_method => true,
        }
      )
      result.success?.should == true
      transaction = result.transaction
      transaction.customer_details.id.should =~ /\A\d{6,}\z/
      transaction.vault_customer.id.should == transaction.customer_details.id
      credit_card = Braintree::CreditCard.find(transaction.vault_credit_card.token)
      transaction.billing_details.id.should == credit_card.billing_address.id
      transaction.vault_billing_address.id.should == credit_card.billing_address.id
      credit_card.billing_address.first_name.should == "Carl"
      credit_card.billing_address.last_name.should == "Jones"
      credit_card.billing_address.company.should == "Braintree"
      credit_card.billing_address.street_address.should == "123 E Main St"
      credit_card.billing_address.extended_address.should == "Suite 403"
      credit_card.billing_address.locality.should == "Chicago"
      credit_card.billing_address.region.should == "IL"
      credit_card.billing_address.postal_code.should == "60622"
      credit_card.billing_address.country_name.should == "United States of America"
    end

    it "can store the shipping address in the vault" do
      result = Braintree::Transaction.sale(
        :amount => "100",
        :customer => {
          :first_name => "Adam",
          :last_name => "Williams"
        },
        :credit_card => {
          :number => "5105105105105100",
          :expiration_date => "05/2012"
        },
        :shipping => {
          :first_name => "Carl",
          :last_name => "Jones",
          :company => "Braintree",
          :street_address => "123 E Main St",
          :extended_address => "Suite 403",
          :locality => "Chicago",
          :region => "IL",
          :postal_code => "60622",
          :country_name => "United States of America"
        },
        :options => {
          :store_in_vault => true,
          :store_shipping_address_in_vault => true,
        }
      )
      result.success?.should == true
      transaction = result.transaction
      transaction.customer_details.id.should =~ /\A\d{6,}\z/
      transaction.vault_customer.id.should == transaction.customer_details.id
      transaction.vault_shipping_address.id.should == transaction.vault_customer.addresses[0].id
      shipping_address = transaction.vault_customer.addresses[0]
      shipping_address.first_name.should == "Carl"
      shipping_address.last_name.should == "Jones"
      shipping_address.company.should == "Braintree"
      shipping_address.street_address.should == "123 E Main St"
      shipping_address.extended_address.should == "Suite 403"
      shipping_address.locality.should == "Chicago"
      shipping_address.region.should == "IL"
      shipping_address.postal_code.should == "60622"
      shipping_address.country_name.should == "United States of America"
    end

    it "stores a unique number identifier in the vault" do
      result = Braintree::Transaction.sale(
        :amount => "100",
        :credit_card => {
          :number => "5105105105105100",
          :expiration_date => "05/2012"
        },
        :options => { :store_in_vault => true }
      )

      result.success?.should == true

      transaction = result.transaction
      transaction.credit_card_details.unique_number_identifier.should_not be_nil
    end

    it "submits for settlement if given transaction[options][submit_for_settlement]" do
      result = Braintree::Transaction.sale(
        :amount => "100",
        :credit_card => {
          :number => "5105105105105100",
          :expiration_date => "05/2012"
        },
        :options => {
          :submit_for_settlement => true
        }
      )
      result.success?.should == true
      result.transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
    end

    it "can specify the customer id and payment method token" do
      customer_id = "customer_#{rand(10**10)}"
      payment_method_token = "credit_card_#{rand(10**10)}"
      result = Braintree::Transaction.sale(
        :amount => "100",
        :customer => {
          :id => customer_id,
          :first_name => "Adam",
          :last_name => "Williams"
        },
        :credit_card => {
          :token => payment_method_token,
          :number => "5105105105105100",
          :expiration_date => "05/2012"
        },
        :options => {
          :store_in_vault => true
        }
      )
      result.success?.should == true
      transaction = result.transaction
      transaction.customer_details.id.should == customer_id
      transaction.vault_customer.id.should == customer_id
      transaction.credit_card_details.token.should == payment_method_token
      transaction.vault_credit_card.token.should == payment_method_token
    end

    it "can specify existing shipping address" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )
      address = Braintree::Address.create!(
        :customer_id => customer.id,
        :street_address => '123 Fake St.'
      )
      result = Braintree::Transaction.sale(
        :amount => "100",
        :customer_id => customer.id,
        :shipping_address_id => address.id
      )
      result.success?.should == true
      transaction = result.transaction
      transaction.shipping_details.street_address.should == '123 Fake St.'
      transaction.customer_details.id.should == customer.id
      transaction.shipping_details.id.should == address.id
    end

    it "returns an error result if validations fail" do
      params = {
        :transaction => {
          :amount => nil,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          }
        }
      }
      result = Braintree::Transaction.sale(params[:transaction])
      result.success?.should == false
      result.params.should == {:transaction => {:type => 'sale', :amount => nil, :credit_card => {:expiration_date => "05/2009"}}}
      result.errors.for(:transaction).on(:amount)[0].code.should == Braintree::ErrorCodes::Transaction::AmountIsRequired
    end

    it "skips advanced fraud checking if transaction[options][skip_advanced_fraud_checking] is set to true" do
      with_advanced_fraud_integration_merchant do
        result = Braintree::Transaction.sale(
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          },
          :options => {
            :skip_advanced_fraud_checking => true
          }
        )
        result.success?.should == true
        result.transaction.risk_data.should be_nil
      end
    end

    it "works with Apple Pay params" do
      params = {
        :amount => "3.12",
        :apple_pay_card => {
          :number => "370295001292109",
          :cardholder_name => "JANE SMITH",
          :cryptogram => "AAAAAAAA/COBt84dnIEcwAA3gAAGhgEDoLABAAhAgAABAAAALnNCLw==",
          :expiration_month => "10",
          :expiration_year => "14",
          :eci_indicator => "07",
        }
      }
      result = Braintree::Transaction.sale(params)
      result.success?.should == true
      result.transaction.status.should == Braintree::Transaction::Status::Authorized
    end

    context "Android Pay params" do
      it "works with full params" do
        params = {
          :amount => "3.12",
          :android_pay_card => {
            :number => "4012888888881881",
            :cryptogram => "AAAAAAAA/COBt84dnIEcwAA3gAAGhgEDoLABAAhAgAABAAAALnNCLw==",
            :google_transaction_id => "25469d622c1dd37cb1a403c6d438e850",
            :expiration_month => "10",
            :expiration_year => "14",
            :source_card_type => "Visa",
            :source_card_last_four => "1111",
            :eci_indicator => "05",
          }
        }
        result = Braintree::Transaction.sale(params)
        result.success?.should == true
        result.transaction.status.should == Braintree::Transaction::Status::Authorized
      end

      it "works with only number, cryptogram, expiration and transaction ID (network tokenized card)" do
        params = {
          :amount => "3.12",
          :android_pay_card => {
            :number => "4012888888881881",
            :cryptogram => "AAAAAAAA/COBt84dnIEcwAA3gAAGhgEDoLABAAhAgAABAAAALnNCLw==",
            :google_transaction_id => "25469d622c1dd37cb1a403c6d438e850",
            :expiration_month => "10",
            :expiration_year => "14",
          }
        }
        result = Braintree::Transaction.sale(params)
        result.success?.should == true
        result.transaction.status.should == Braintree::Transaction::Status::Authorized
      end

      it "works with only number, expiration and transaction ID (non-tokenized card)" do
        params = {
          :amount => "3.12",
          :android_pay_card => {
            :number => "4012888888881881",
            :google_transaction_id => "25469d622c1dd37cb1a403c6d438e850",
            :expiration_month => "10",
            :expiration_year => "14",
          }
        }
        result = Braintree::Transaction.sale(params)
        result.success?.should == true
        result.transaction.status.should == Braintree::Transaction::Status::Authorized
      end
    end

    context "Amex Pay with Points" do
      context "transaction creation" do
        it "succeeds when submit_for_settlement is true" do
          result = Braintree::Transaction.sale(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :merchant_account_id => SpecHelper::FakeAmexDirectMerchantAccountId,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::AmexPayWithPoints::Success,
              :expiration_date => "05/2009"
            },
            :options => {
              :submit_for_settlement => true,
              :amex_rewards => {
                :request_id => "ABC123",
                :points => "1000",
                :currency_amount => "10.00",
                :currency_iso_code => "USD"
              }
            }
          )
          result.success?.should == true
          result.transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
        end

        it "succeeds even if the card is ineligible" do
          result = Braintree::Transaction.sale(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :merchant_account_id => SpecHelper::FakeAmexDirectMerchantAccountId,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::AmexPayWithPoints::IneligibleCard,
              :expiration_date => "05/2009"
            },
            :options => {
              :submit_for_settlement => true,
              :amex_rewards => {
                :request_id => "ABC123",
                :points => "1000",
                :currency_amount => "10.00",
                :currency_iso_code => "USD"
              }
            }
          )
          result.success?.should == true
          result.transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
        end

        it "succeeds even if the card's balance is insufficient" do
          result = Braintree::Transaction.sale(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :merchant_account_id => SpecHelper::FakeAmexDirectMerchantAccountId,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::AmexPayWithPoints::InsufficientPoints,
              :expiration_date => "05/2009"
            },
            :options => {
              :submit_for_settlement => true,
              :amex_rewards => {
                :request_id => "ABC123",
                :points => "1000",
                :currency_amount => "10.00",
                :currency_iso_code => "USD"
              }
            }
          )
          result.success?.should == true
          result.transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
        end
      end

      context "submit for settlement" do
        it "succeeds" do
          result = Braintree::Transaction.sale(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :merchant_account_id => SpecHelper::FakeAmexDirectMerchantAccountId,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::AmexPayWithPoints::Success,
              :expiration_date => "05/2009"
            },
            :options => {
              :amex_rewards => {
                :request_id => "ABC123",
                :points => "1000",
                :currency_amount => "10.00",
                :currency_iso_code => "USD"
              }
            }
          )
          result.success?.should == true

          result = Braintree::Transaction.submit_for_settlement(result.transaction.id)
          result.success?.should == true
          result.transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
        end

        it "succeeds even if the card is ineligible" do
          result = Braintree::Transaction.sale(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :merchant_account_id => SpecHelper::FakeAmexDirectMerchantAccountId,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::AmexPayWithPoints::IneligibleCard,
              :expiration_date => "05/2009"
            },
            :options => {
              :amex_rewards => {
                :request_id => "ABC123",
                :points => "1000",
                :currency_amount => "10.00",
                :currency_iso_code => "USD"
              }
            }
          )
          result.success?.should == true
          result.transaction.status.should == Braintree::Transaction::Status::Authorized

          result = Braintree::Transaction.submit_for_settlement(result.transaction.id)
          result.success?.should == true
          result.transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
        end

        it "succeeds even if the card's balance is insufficient" do
          result = Braintree::Transaction.sale(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :merchant_account_id => SpecHelper::FakeAmexDirectMerchantAccountId,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::AmexPayWithPoints::IneligibleCard,
              :expiration_date => "05/2009"
            },
            :options => {
              :amex_rewards => {
                :request_id => "ABC123",
                :points => "1000",
                :currency_amount => "10.00",
                :currency_iso_code => "USD"
              }
            }
          )
          result.success?.should == true
          result.transaction.status.should == Braintree::Transaction::Status::Authorized

          result = Braintree::Transaction.submit_for_settlement(result.transaction.id)
          result.success?.should == true
          result.transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
        end
      end
    end
  end

  describe "self.sale!" do
    it "returns the transaction if valid" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      transaction.id.should =~ /^\w{6,}$/
      transaction.type.should == "sale"
      transaction.amount.should == BigDecimal(Braintree::Test::TransactionAmounts::Authorize)
      transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      transaction.credit_card_details.expiration_date.should == "05/2009"
    end

    it "raises a ValidationsFailed if invalid" do
      expect do
        Braintree::Transaction.sale!(
          :amount => nil,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          }
        )
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "self.submit_for_settlement" do
    it "returns a successful result if successful" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )
      result = Braintree::Transaction.submit_for_settlement(transaction.id)
      result.success?.should == true
    end

    it "can submit a specific amount for settlement" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )
      transaction.amount.should == BigDecimal("1000.00")
      result = Braintree::Transaction.submit_for_settlement(transaction.id, "999.99")
      result.success?.should == true
      result.transaction.amount.should == BigDecimal("999.99")
      result.transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
      result.transaction.updated_at.between?(Time.now - 60, Time.now).should == true
    end

    it "returns a successful result if order_id is passed in as an options hash" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )
      options = { :order_id => "ABC123" }
      result = Braintree::Transaction.submit_for_settlement(transaction.id, nil, options)
      result.success?.should == true
      result.transaction.order_id.should == "ABC123"
      result.transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
    end

    it "returns a successful result if descritpors are passed in as an options hash" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )

      options = {
        :descriptor => {
          :name => '123*123456789012345678',
          :phone => '3334445555',
          :url => "ebay.com"
        }
      }

      result = Braintree::Transaction.submit_for_settlement(transaction.id, nil, options)
      result.success?.should == true
      result.transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
      result.transaction.descriptor.name.should == '123*123456789012345678'
      result.transaction.descriptor.phone.should == '3334445555'
      result.transaction.descriptor.url.should == 'ebay.com'
    end

    it "raises an error if an invalid option is passed in" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )

      options = { :order_id => "ABC123", :invalid_option => "i'm invalid" }

      expect do
        Braintree::Transaction.submit_for_settlement(transaction.id, nil, options)
      end.to raise_error(ArgumentError)
    end

    it "returns an error result if settlement is too large" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )
      transaction.amount.should == BigDecimal("1000.00")
      result = Braintree::Transaction.submit_for_settlement(transaction.id, "1000.01")
      result.success?.should == false
      result.errors.for(:transaction).on(:amount)[0].code.should == Braintree::ErrorCodes::Transaction::SettlementAmountIsTooLarge
      result.params[:transaction][:amount].should == "1000.01"
    end

    it "returns an error result if status is not authorized" do
      transaction = Braintree::Transaction.sale(
        :amount => Braintree::Test::TransactionAmounts::Decline,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      ).transaction
      result = Braintree::Transaction.submit_for_settlement(transaction.id)
      result.success?.should == false
      result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::CannotSubmitForSettlement
    end

    context "service fees" do
      it "returns an error result if amount submitted for settlement is less than service fee amount" do
        transaction = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :merchant_account_id => SpecHelper::NonDefaultSubMerchantAccountId,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "06/2009"
          },
          :service_fee_amount => "1.00"
        ).transaction
        result = Braintree::Transaction.submit_for_settlement(transaction.id, "0.01")
        result.success?.should == false
        result.errors.for(:transaction).on(:amount)[0].code.should == Braintree::ErrorCodes::Transaction::SettlementAmountIsLessThanServiceFeeAmount
      end
    end

    it "succeeds when level 2 data is provided" do
      result = Braintree::Transaction.sale(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::FakeAmexDirectMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::AmexPayWithPoints::Success,
          :expiration_date => "05/2009"
        },
        :options => {
          :amex_rewards => {
            :request_id => "ABC123",
            :points => "1000",
            :currency_amount => "10.00",
            :currency_iso_code => "USD"
          }
        }
      )
      result.success?.should == true

      result = Braintree::Transaction.submit_for_settlement(result.transaction.id, nil, :tax_amount => "2.00", :tax_exempt => false, :purchase_order_number => "0Rd3r#")
      result.success?.should == true
      result.transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
    end

    it "succeeds when level 3 data is provided" do
      result = Braintree::Transaction.sale(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::FakeAmexDirectMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::AmexPayWithPoints::Success,
          :expiration_date => "05/2009"
        },
        :options => {
          :amex_rewards => {
            :request_id => "ABC123",
            :points => "1000",
            :currency_amount => "10.00",
            :currency_iso_code => "USD"
          }
        }
      )
      result.success?.should == true

      result = Braintree::Transaction.submit_for_settlement(
        result.transaction.id,
        nil,
        :discount_amount => "2.00",
        :shipping_amount => "1.23",
        :ships_from_postal_code => "90210",
        :line_items => [
          {
            :quantity => 1,
            :unit_amount => 1,
            :name => "New line item",
            :kind => "debit",
            :total_amount => "18.00",
            :discount_amount => "12.00",
            :tax_amount => "0",
          },
        ]
      )
      result.success?.should == true
      result.transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
    end
  end

  describe "self.submit_for_settlement!" do
    it "returns the transaction if successful" do
      original_transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )
      options = { :order_id => "ABC123" }
      transaction = Braintree::Transaction.submit_for_settlement!(original_transaction.id, "0.01", options)
      transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
      transaction.id.should == original_transaction.id
      transaction.order_id.should == options[:order_id]
    end

    it "raises a ValidationsFailed if unsuccessful" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )
      transaction.amount.should == BigDecimal("1000.00")
      expect do
        Braintree::Transaction.submit_for_settlement!(transaction.id, "1000.01")
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "update details" do
    context "when status is submitted_for_settlement" do
      let(:transaction) do
        Braintree::Transaction.sale!(
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :merchant_account_id => SpecHelper::DefaultMerchantAccountId,
          :descriptor => {
            :name => '123*123456789012345678',
            :phone => '3334445555',
            :url => "ebay.com"
          },
          :order_id => '123',
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "06/2009"
          },
          :options => {
            :submit_for_settlement => true
          }
        )
      end

      it "successfully updates details" do
        result = Braintree::Transaction.update_details(transaction.id, {
          :amount => Braintree::Test::TransactionAmounts::Authorize.to_f - 1,
          :descriptor => {
            :name => '456*123456789012345678',
            :phone => '3334445555',
            :url => "ebay.com",
          },
          :order_id => '456'
        })
        result.success?.should == true
        result.transaction.amount.should == BigDecimal(Braintree::Test::TransactionAmounts::Authorize) - 1
        result.transaction.order_id.should == '456'
        result.transaction.descriptor.name.should ==  '456*123456789012345678'
      end

      it "raises an error when a key is invalid" do
        expect do
          Braintree::Transaction.update_details(transaction.id, {
            :invalid_key => Braintree::Test::TransactionAmounts::Authorize.to_f - 1,
            :descriptor => {
              :name => '456*123456789012345678',
              :phone => '3334445555',
              :url => "ebay.com",
            },
            :order_id => '456'
          })
        end.to raise_error(ArgumentError)
      end

      describe "errors" do
        it "returns an error response when the settlement amount is invalid" do
          result = Braintree::Transaction.update_details(transaction.id, {
            :amount => "10000",
            :descriptor => {
              :name => '456*123456789012345678',
              :phone => '3334445555',
              :url => "ebay.com",
            },
            :order_id => '456'
          })
          result.success?.should == false
          result.errors.for(:transaction).on(:amount)[0].code.should == Braintree::ErrorCodes::Transaction::SettlementAmountIsTooLarge
        end

        it "returns an error response when the descriptor is invalid" do
          result = Braintree::Transaction.update_details(transaction.id, {
            :amount => Braintree::Test::TransactionAmounts::Authorize.to_f - 1,
            :descriptor => {
              :name => 'invalid descriptor name',
              :phone => 'invalid phone',
              :url => '12345678901234'
            },
            :order_id => '456'
          })
          result.success?.should == false
          result.errors.for(:transaction).for(:descriptor).on(:name)[0].code.should == Braintree::ErrorCodes::Descriptor::NameFormatIsInvalid
          result.errors.for(:transaction).for(:descriptor).on(:phone)[0].code.should == Braintree::ErrorCodes::Descriptor::PhoneFormatIsInvalid
          result.errors.for(:transaction).for(:descriptor).on(:url)[0].code.should == Braintree::ErrorCodes::Descriptor::UrlFormatIsInvalid
        end

        it "returns an error response when the order_id is invalid" do
          result = Braintree::Transaction.update_details(transaction.id, {
            :amount => Braintree::Test::TransactionAmounts::Authorize.to_f - 1,
            :descriptor => {
              :name => '456*123456789012345678',
              :phone => '3334445555',
              :url => "ebay.com",
            },
            :order_id => 'x' * 256
          })
          result.success?.should == false
          result.errors.for(:transaction).on(:order_id)[0].code.should == Braintree::ErrorCodes::Transaction::OrderIdIsTooLong
        end

        it "returns an error on an unsupported processor" do
          transaction = Braintree::Transaction.sale!(
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :merchant_account_id => SpecHelper::FakeAmexDirectMerchantAccountId,
            :descriptor => {
              :name => '123*123456789012345678',
              :phone => '3334445555',
              :url => "ebay.com"
            },
            :order_id => '123',
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::AmexPayWithPoints::Success,
              :expiration_date => "05/2009"
            },
            :options => {
              :submit_for_settlement => true
            }
          )
          result = Braintree::Transaction.update_details(transaction.id, {
            :amount => Braintree::Test::TransactionAmounts::Authorize.to_f - 1,
            :descriptor => {
              :name => '456*123456789012345678',
              :phone => '3334445555',
              :url => "ebay.com",
            },
            :order_id => '456'
          })
          result.success?.should == false
          result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::ProcessorDoesNotSupportUpdatingTransactionDetails
        end
      end
    end

    context "when status is not submitted_for_settlement" do
      it "returns an error" do
        transaction = Braintree::Transaction.sale!(
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :merchant_account_id => SpecHelper::DefaultMerchantAccountId,
          :descriptor => {
            :name => '123*123456789012345678',
            :phone => '3334445555',
            :url => "ebay.com"
          },
          :order_id => '123',
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "06/2009"
          }
        )
        result = Braintree::Transaction.update_details(transaction.id, {
          :amount => Braintree::Test::TransactionAmounts::Authorize.to_f - 1,
          :descriptor => {
            :name => '456*123456789012345678',
            :phone => '3334445555',
            :url => "ebay.com",
          },
          :order_id => '456'
        })
        result.success?.should == false
        result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::CannotUpdateTransactionDetailsNotSubmittedForSettlement
      end
    end

  end

  describe "submit for partial settlement" do
    it "successfully submits multiple times for partial settlement" do
      authorized_transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::DefaultMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )

      result = Braintree::Transaction.submit_for_partial_settlement(authorized_transaction.id, 100)
      result.success?.should == true
      partial_settlement_transaction1 = result.transaction
      partial_settlement_transaction1.amount.should == 100
      partial_settlement_transaction1.type.should == Braintree::Transaction::Type::Sale
      partial_settlement_transaction1.status.should == Braintree::Transaction::Status::SubmittedForSettlement
      partial_settlement_transaction1.authorized_transaction_id.should == authorized_transaction.id

      refreshed_authorized_transaction = Braintree::Transaction.find(authorized_transaction.id)
      refreshed_authorized_transaction.status.should == Braintree::Transaction::Status::SettlementPending
      refreshed_authorized_transaction.partial_settlement_transaction_ids.should == [partial_settlement_transaction1.id]

      result = Braintree::Transaction.submit_for_partial_settlement(authorized_transaction.id, 800)
      result.success?.should == true
      partial_settlement_transaction2 = result.transaction
      partial_settlement_transaction2.amount.should == 800
      partial_settlement_transaction2.type.should == Braintree::Transaction::Type::Sale
      partial_settlement_transaction2.status.should == Braintree::Transaction::Status::SubmittedForSettlement
      partial_settlement_transaction2.authorized_transaction_id.should == authorized_transaction.id

      refreshed_authorized_transaction = Braintree::Transaction.find(authorized_transaction.id)
      refreshed_authorized_transaction.status.should == Braintree::Transaction::Status::SettlementPending
      refreshed_authorized_transaction.partial_settlement_transaction_ids.sort.should == [partial_settlement_transaction1.id, partial_settlement_transaction2.id].sort
    end

    it "allows partial settlement to be submitted with order_id" do
      authorized_transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::DefaultMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )

      result = Braintree::Transaction.submit_for_partial_settlement(authorized_transaction.id, 100, :order_id => 1234)
      result.success?.should == true
      partial_settlement_transaction = result.transaction
      partial_settlement_transaction.order_id.should == "1234"
    end

    it "returns an error with an order_id that's too long" do
      authorized_transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::DefaultMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )

      result = Braintree::Transaction.submit_for_partial_settlement(authorized_transaction.id, 100, :order_id => "1"*256)
      result.success?.should == false
      result.errors.for(:transaction).on(:order_id)[0].code.should == Braintree::ErrorCodes::Transaction::OrderIdIsTooLong
    end

    it "allows partial settlement to be submitted with descriptors" do
      authorized_transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::DefaultMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )

      result = Braintree::Transaction.submit_for_partial_settlement(
        authorized_transaction.id,
        100,
        :descriptor => { :name => "123*123456789012345678", :phone => "5555551234", :url => "url.com" }
      )
      result.success?.should == true
      partial_settlement_transaction = result.transaction
      partial_settlement_transaction.descriptor.name.should == "123*123456789012345678"
      partial_settlement_transaction.descriptor.phone.should == "5555551234"
      partial_settlement_transaction.descriptor.url.should == "url.com"
    end

    it "returns an error with a descriptor in an invalid format" do
      authorized_transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::DefaultMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )

      result = Braintree::Transaction.submit_for_partial_settlement(
        authorized_transaction.id,
        100,
        :descriptor => {
          :name => "invalid_format",
          :phone => '%bad4445555',
          :url => '12345678901234'
        }
      )
      result.success?.should == false
      result.errors.for(:transaction).for(:descriptor).on(:name)[0].code.should == Braintree::ErrorCodes::Descriptor::NameFormatIsInvalid
      result.errors.for(:transaction).for(:descriptor).on(:phone)[0].code.should == Braintree::ErrorCodes::Descriptor::PhoneFormatIsInvalid
      result.errors.for(:transaction).for(:descriptor).on(:url)[0].code.should == Braintree::ErrorCodes::Descriptor::UrlFormatIsInvalid
    end

    it "returns an error with an unsupported processor" do
      authorized_transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::FakeAmexDirectMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::AmexPayWithPoints::Success,
          :expiration_date => "05/2009"
        }
      )

      result = Braintree::Transaction.submit_for_partial_settlement(authorized_transaction.id, 100)
      result.success?.should == false
      result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::ProcessorDoesNotSupportPartialSettlement
    end

    it "returns an error with an invalid payment instrument type" do
      authorized_transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::FakeVenmoAccountMerchantAccountId,
        :payment_method_nonce => Braintree::Test::Nonce::VenmoAccount
      )

      result = Braintree::Transaction.submit_for_partial_settlement(authorized_transaction.id, 100)
      result.success?.should == false
      result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::PaymentInstrumentTypeIsNotAccepted
    end

    it "returns an error result if settlement amount greater than authorized amount" do
      authorized_transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::DefaultMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )

      result = Braintree::Transaction.submit_for_partial_settlement(authorized_transaction.id, 100)
      result.success?.should == true

      result = Braintree::Transaction.submit_for_partial_settlement(authorized_transaction.id, 901)
      result.success?.should == false
      result.errors.for(:transaction).on(:amount)[0].code.should == Braintree::ErrorCodes::Transaction::SettlementAmountIsTooLarge
    end

    it "returns an error result if status is not authorized" do
      authorized_transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::DefaultMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )

      result = Braintree::Transaction.void(authorized_transaction.id)
      result.success?.should == true

      result = Braintree::Transaction.submit_for_partial_settlement(authorized_transaction.id, 100)
      result.success?.should == false
      result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::CannotSubmitForSettlement
    end
  end

  describe "self.submit_for_partial_settlement!" do
    it "returns the transaction if successful" do
      original_transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )
      options = { :order_id => "ABC123" }
      transaction = Braintree::Transaction.submit_for_partial_settlement!(original_transaction.id, "0.01", options)
      transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
      transaction.order_id.should == options[:order_id]
    end

    it "raises a ValidationsFailed if unsuccessful" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )
      transaction.amount.should == BigDecimal("1000.00")
      expect do
        Braintree::Transaction.submit_for_partial_settlement!(transaction.id, "1000.01")
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "self.release_from_escrow" do
    it "returns the transaction if successful" do
      original_transaction = create_escrowed_transcation

      result = Braintree::Transaction.release_from_escrow(original_transaction.id)
      result.transaction.escrow_status.should == Braintree::Transaction::EscrowStatus::ReleasePending
    end

    it "returns an error result if escrow_status is not HeldForEscrow" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::NonDefaultSubMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        },
        :service_fee_amount => '1.00'
      )

      transaction.escrow_status.should be_nil

      result = Braintree::Transaction.release_from_escrow(transaction.id)
      result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::CannotReleaseFromEscrow
    end
  end

  describe "self.release_from_escrow!" do
    it "returns the transaction when successful" do
      original_transaction = create_escrowed_transcation

      transaction = Braintree::Transaction.release_from_escrow!(original_transaction.id)
      transaction.escrow_status.should == Braintree::Transaction::EscrowStatus::ReleasePending
    end

    it "raises an error when transaction is not successful" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::NonDefaultSubMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        },
        :service_fee_amount => '1.00'
      )

      transaction.escrow_status.should be_nil

      expect do
        Braintree::Transaction.release_from_escrow!(transaction.id)
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "self.cancel_release" do
    it "returns the transaction if successful" do
      transaction = create_escrowed_transcation
      result = Braintree::Transaction.release_from_escrow(transaction.id)
      result.transaction.escrow_status.should == Braintree::Transaction::EscrowStatus::ReleasePending

      result = Braintree::Transaction.cancel_release(transaction.id)

      result.success?.should be(true)
      result.transaction.escrow_status.should == Braintree::Transaction::EscrowStatus::Held
    end

    it "returns an error result if escrow_status is not ReleasePending" do
      transaction = create_escrowed_transcation

      result = Braintree::Transaction.cancel_release(transaction.id)

      result.success?.should be(false)
      result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::CannotCancelRelease
    end
  end

  describe "self.cancel_release!" do
    it "returns the transaction when release is cancelled" do
      transaction = create_escrowed_transcation
      result = Braintree::Transaction.release_from_escrow(transaction.id)
      result.transaction.escrow_status.should == Braintree::Transaction::EscrowStatus::ReleasePending

      transaction = Braintree::Transaction.cancel_release!(transaction.id)

      transaction.escrow_status.should == Braintree::Transaction::EscrowStatus::Held
    end

    it "raises an error when release cannot be cancelled" do
      transaction = create_escrowed_transcation

      expect {
        transaction = Braintree::Transaction.cancel_release!(transaction.id)
      }.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "self.credit" do
    it "returns a successful result with type=credit if successful" do
      result = Braintree::Transaction.credit(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      result.success?.should == true
      result.transaction.id.should =~ /^\w{6,}$/
      result.transaction.type.should == "credit"
      result.transaction.amount.should == BigDecimal(Braintree::Test::TransactionAmounts::Authorize)
      result.transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      result.transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      result.transaction.credit_card_details.expiration_date.should == "05/2009"
    end

    it "returns an error result if validations fail" do
      params = {
        :transaction => {
          :amount => nil,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          }
        }
      }
      result = Braintree::Transaction.credit(params[:transaction])
      result.success?.should == false
      result.params.should == {:transaction => {:type => 'credit', :amount => nil, :credit_card => {:expiration_date => "05/2009"}}}
      result.errors.for(:transaction).on(:amount)[0].code.should == Braintree::ErrorCodes::Transaction::AmountIsRequired
    end

    it "allows merchant account to be specified" do
      result = Braintree::Transaction.credit(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::NonDefaultMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      result.success?.should == true
      result.transaction.merchant_account_id.should == SpecHelper::NonDefaultMerchantAccountId
    end

    it "uses default merchant account when it is not specified" do
      result = Braintree::Transaction.credit(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      result.success?.should == true
      result.transaction.merchant_account_id.should == SpecHelper::DefaultMerchantAccountId
    end

    it "disallows service fee on a credit" do
      params = {
        :transaction => {
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          },
          :service_fee_amount => "1.00"
        }
      }
      result = Braintree::Transaction.credit(params[:transaction])
      result.success?.should == false
      result.errors.for(:transaction).on(:base).map(&:code).should include(Braintree::ErrorCodes::Transaction::ServiceFeeIsNotAllowedOnCredits)
    end
  end

  describe "self.credit!" do
    it "returns the transaction if valid" do
      transaction = Braintree::Transaction.credit!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      transaction.id.should =~ /^\w{6,}$/
      transaction.type.should == "credit"
      transaction.amount.should == BigDecimal(Braintree::Test::TransactionAmounts::Authorize)
      transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      transaction.credit_card_details.expiration_date.should == "05/2009"
    end

    it "raises a ValidationsFailed if invalid" do
      expect do
        Braintree::Transaction.credit!(
          :amount => nil,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          }
        )
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "self.create_from_transparent_redirect" do
    it "returns a successful result if successful" do
      params = {
        :transaction => {
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          }
        }
      }
      tr_data_params = {
        :transaction => {
          :type => "sale"
        }
      }
      tr_data = Braintree::TransparentRedirect.transaction_data({:redirect_url => "http://example.com"}.merge(tr_data_params))
      query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params, Braintree::Transaction.create_transaction_url)
      result = Braintree::Transaction.create_from_transparent_redirect(query_string_response)

      result.success?.should == true
      transaction = result.transaction
      transaction.type.should == "sale"
      transaction.amount.should == BigDecimal("1000.00")
      transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
      transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
      transaction.credit_card_details.expiration_date.should == "05/2009"
    end

    it "raises an error with a message if given invalid params" do
      params = {
        :transaction => {
          :bad => "value",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          }
        }
      }
      tr_data_params = {
        :transaction => {
          :type => "sale"
        }
      }
      tr_data = Braintree::TransparentRedirect.transaction_data({:redirect_url => "http://example.com"}.merge(tr_data_params))
      query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params, Braintree::Transaction.create_transaction_url)

      expect do
        Braintree::Transaction.create_from_transparent_redirect(query_string_response)
      end.to raise_error(Braintree::AuthorizationError, "Invalid params: transaction[bad]")
    end

    it "can put any param in tr_data" do
      params = {

      }
      tr_data_params = {
        :transaction => {
          :amount => "100.00",
          :order_id => "123",
          :channel => "MyShoppingCartProvider",
          :type => "sale",
          :credit_card => {
            :cardholder_name => "The Cardholder",
            :number => "5105105105105100",
            :expiration_date => "05/2011",
            :cvv => "123"
          },
          :customer => {
            :first_name => "Dan",
            :last_name => "Smith",
            :company => "Braintree",
            :email => "dan@example.com",
            :phone => "419-555-1234",
            :fax => "419-555-1235",
            :website => "http://braintreepayments.com"
          },
          :billing => {
            :first_name => "Carl",
            :last_name => "Jones",
            :company => "Braintree",
            :street_address => "123 E Main St",
            :extended_address => "Suite 403",
            :locality => "Chicago",
            :region => "IL",
            :postal_code => "60622",
            :country_name => "United States of America"
          },
          :shipping => {
            :first_name => "Andrew",
            :last_name => "Mason",
            :company => "Braintree",
            :street_address => "456 W Main St",
            :extended_address => "Apt 2F",
            :locality => "Bartlett",
            :region => "IL",
            :postal_code => "60103",
            :country_name => "United States of America"
          }
        }
      }
      tr_data = Braintree::TransparentRedirect.transaction_data({:redirect_url => "http://example.com"}.merge(tr_data_params))
      query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params, Braintree::Transaction.create_transaction_url)
      result = Braintree::Transaction.create_from_transparent_redirect(query_string_response)

      transaction = result.transaction
      transaction.id.should =~ /\A\w{6,}\z/
      transaction.type.should == "sale"
      transaction.status.should == Braintree::Transaction::Status::Authorized
      transaction.amount.should == BigDecimal("100.00")
      transaction.order_id.should == "123"
      transaction.channel.should == "MyShoppingCartProvider"
      transaction.processor_response_code.should == "1000"
      transaction.authorization_expires_at.between?(Time.now, Time.now + (60 * 60 * 24 * 60)).should == true
      transaction.created_at.between?(Time.now - 60, Time.now).should == true
      transaction.updated_at.between?(Time.now - 60, Time.now).should == true
      transaction.credit_card_details.bin.should == "510510"
      transaction.credit_card_details.last_4.should == "5100"
      transaction.credit_card_details.cardholder_name.should == "The Cardholder"
      transaction.credit_card_details.masked_number.should == "510510******5100"
      transaction.credit_card_details.card_type.should == "MasterCard"
      transaction.avs_error_response_code.should == nil
      transaction.avs_postal_code_response_code.should == "M"
      transaction.avs_street_address_response_code.should == "M"
      transaction.cvv_response_code.should == "M"
      transaction.customer_details.first_name.should == "Dan"
      transaction.customer_details.last_name.should == "Smith"
      transaction.customer_details.company.should == "Braintree"
      transaction.customer_details.email.should == "dan@example.com"
      transaction.customer_details.phone.should == "419-555-1234"
      transaction.customer_details.fax.should == "419-555-1235"
      transaction.customer_details.website.should == "http://braintreepayments.com"
      transaction.billing_details.first_name.should == "Carl"
      transaction.billing_details.last_name.should == "Jones"
      transaction.billing_details.company.should == "Braintree"
      transaction.billing_details.street_address.should == "123 E Main St"
      transaction.billing_details.extended_address.should == "Suite 403"
      transaction.billing_details.locality.should == "Chicago"
      transaction.billing_details.region.should == "IL"
      transaction.billing_details.postal_code.should == "60622"
      transaction.billing_details.country_name.should == "United States of America"
      transaction.shipping_details.first_name.should == "Andrew"
      transaction.shipping_details.last_name.should == "Mason"
      transaction.shipping_details.company.should == "Braintree"
      transaction.shipping_details.street_address.should == "456 W Main St"
      transaction.shipping_details.extended_address.should == "Apt 2F"
      transaction.shipping_details.locality.should == "Bartlett"
      transaction.shipping_details.region.should == "IL"
      transaction.shipping_details.postal_code.should == "60103"
      transaction.shipping_details.country_name.should == "United States of America"
    end

    it "returns an error result if validations fail" do
      params = {
        :transaction => {
          :amount => "",
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          }
        }
      }
      tr_data_params = {
        :transaction => {
          :type => "sale"
        }
      }
      tr_data = Braintree::TransparentRedirect.transaction_data({:redirect_url => "http://example.com"}.merge(tr_data_params))
      query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params, Braintree::Transaction.create_transaction_url)
      result = Braintree::Transaction.create_from_transparent_redirect(query_string_response)

      result.success?.should == false
      result.params[:transaction].should == {:amount => "", :type => "sale", :credit_card => {:expiration_date => "05/2009"}}
      result.errors.for(:transaction).on(:amount)[0].code.should == Braintree::ErrorCodes::Transaction::AmountIsRequired
    end
  end

  describe "self.find" do
    it "finds the transaction with the given id" do
      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      result.success?.should == true
      created_transaction = result.transaction
      found_transaction = Braintree::Transaction.find(created_transaction.id)
      found_transaction.should == created_transaction
      found_transaction.graphql_id.should_not be_nil
    end

    it "finds the vaulted transaction with the given id" do
      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        },
        :options => { :store_in_vault => true }
      )
      result.success?.should == true
      created_transaction = result.transaction
      found_transaction = Braintree::Transaction.find(created_transaction.id)
      found_transaction.should == created_transaction

      found_transaction.credit_card_details.unique_number_identifier.should_not be_nil
    end

    it "raises a NotFoundError exception if transaction cannot be found" do
      expect do
        Braintree::Transaction.find("invalid-id")
      end.to raise_error(Braintree::NotFoundError, 'transaction with id "invalid-id" not found')
    end

    context "disbursement_details" do
      it "includes disbursement_details on found transactions" do
        found_transaction = Braintree::Transaction.find("deposittransaction")

        found_transaction.disbursed?.should == true
        disbursement = found_transaction.disbursement_details

        disbursement.disbursement_date.should == "2013-04-10"
        disbursement.settlement_amount.should == "100.00"
        disbursement.settlement_currency_iso_code.should == "USD"
        disbursement.settlement_currency_exchange_rate.should == "1"
        disbursement.funds_held?.should == false
        disbursement.success?.should be(true)
      end

      it "is not disbursed" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          }
        )
        result.success?.should == true
        created_transaction = result.transaction

        created_transaction.disbursed?.should == false
      end
    end

    context "disputes" do
      it "includes disputes on found transactions" do
        found_transaction = Braintree::Transaction.find("disputedtransaction")

        found_transaction.disputes.count.should == 1

        dispute = found_transaction.disputes.first
        dispute.received_date.should == Date.new(2014, 3, 1)
        dispute.reply_by_date.should == Date.new(2014, 3, 21)
        dispute.amount.should == Braintree::Util.to_big_decimal("250.00")
        dispute.currency_iso_code.should == "USD"
        dispute.reason.should == Braintree::Dispute::Reason::Fraud
        dispute.status.should == Braintree::Dispute::Status::Won
        dispute.transaction_details.amount.should == Braintree::Util.to_big_decimal("1000.00")
        dispute.transaction_details.id.should == "disputedtransaction"
        dispute.kind.should == Braintree::Dispute::Kind::Chargeback
        dispute.date_opened.should == Date.new(2014, 3, 1)
        dispute.date_won.should == Date.new(2014, 3, 7)
      end

      it "includes disputes on found transactions" do
        found_transaction = Braintree::Transaction.find("retrievaltransaction")

        found_transaction.disputes.count.should == 1

        dispute = found_transaction.disputes.first
        dispute.amount.should == Braintree::Util.to_big_decimal("1000.00")
        dispute.currency_iso_code.should == "USD"
        dispute.reason.should == Braintree::Dispute::Reason::Retrieval
        dispute.status.should == Braintree::Dispute::Status::Open
        dispute.transaction_details.amount.should == Braintree::Util.to_big_decimal("1000.00")
        dispute.transaction_details.id.should == "retrievaltransaction"
      end

      it "is not disputed" do
        result = Braintree::Transaction.create(
          :type => "sale",
          :amount => Braintree::Test::TransactionAmounts::Authorize,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          }
        )
        result.success?.should == true
        created_transaction = result.transaction

        created_transaction.disputes.should == []
      end
    end

    context "three_d_secure_info" do
      it "returns all the three_d_secure_info" do
        transaction = Braintree::Transaction.find("threedsecuredtransaction")

        transaction.three_d_secure_info.enrolled.should == "Y"
        transaction.three_d_secure_info.should be_liability_shifted
        transaction.three_d_secure_info.should be_liability_shift_possible
        transaction.three_d_secure_info.status.should == "authenticate_successful"
        transaction.three_d_secure_info.cavv.should == "somebase64value"
        transaction.three_d_secure_info.xid.should == "xidvalue"
        transaction.three_d_secure_info.eci_flag.should == "07"
        transaction.three_d_secure_info.three_d_secure_version.should == "1.0.2"
        transaction.three_d_secure_info.ds_transaction_id.should == "dstxnid"
      end

      it "is nil if the transaction wasn't 3d secured" do
        transaction = Braintree::Transaction.find("settledtransaction")

        transaction.three_d_secure_info.should be_nil
      end
    end

    context "paypal" do
      it "returns all the required paypal fields" do
        transaction = Braintree::Transaction.find("settledtransaction")

        transaction.paypal_details.debug_id.should_not be_nil
        transaction.paypal_details.payer_email.should_not be_nil
        transaction.paypal_details.authorization_id.should_not be_nil
        transaction.paypal_details.payer_id.should_not be_nil
        transaction.paypal_details.payer_first_name.should_not be_nil
        transaction.paypal_details.payer_last_name.should_not be_nil
        transaction.paypal_details.payer_status.should_not be_nil
        transaction.paypal_details.seller_protection_status.should_not be_nil
        transaction.paypal_details.capture_id.should_not be_nil
        transaction.paypal_details.refund_id.should_not be_nil
        transaction.paypal_details.transaction_fee_amount.should_not be_nil
        transaction.paypal_details.transaction_fee_currency_iso_code.should_not be_nil
        transaction.paypal_details.refund_from_transaction_fee_amount.should_not be_nil
        transaction.paypal_details.refund_from_transaction_fee_currency_iso_code.should_not be_nil
      end
    end
  end

  describe "self.hold_in_escrow" do
    it "returns the transaction if successful" do
      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::NonDefaultSubMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "12/12",
        },
        :service_fee_amount => "10.00"
      )

      result.transaction.escrow_status.should be_nil
      result = Braintree::Transaction.hold_in_escrow(result.transaction.id)

      result.success?.should be(true)
      result.transaction.escrow_status.should == Braintree::Transaction::EscrowStatus::HoldPending
    end

    it "returns an error result if the transaction cannot be held in escrow" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::NonDefaultMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )

      result = Braintree::Transaction.hold_in_escrow(transaction.id)
      result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::CannotHoldInEscrow
    end
  end

  describe "self.hold_in_escrow!" do
    it "returns the transaction if successful" do
      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::NonDefaultSubMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "12/12",
        },
        :service_fee_amount => "10.00"
      )

      result.transaction.escrow_status.should be_nil
      transaction = Braintree::Transaction.hold_in_escrow!(result.transaction.id)

      transaction.escrow_status.should == Braintree::Transaction::EscrowStatus::HoldPending
    end

    it "raises an error if the transaction cannot be held in escrow" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :merchant_account_id => SpecHelper::NonDefaultMerchantAccountId,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )

      expect do
        Braintree::Transaction.hold_in_escrow!(transaction.id)
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "self.void" do
    it "returns a successful result if successful" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      result = Braintree::Transaction.void(transaction.id)
      result.success?.should == true
      result.transaction.id.should == transaction.id
      result.transaction.status.should == Braintree::Transaction::Status::Voided
    end

    it "returns an error result if unsuccessful" do
      transaction = Braintree::Transaction.sale(
        :amount => Braintree::Test::TransactionAmounts::Decline,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      ).transaction
      result = Braintree::Transaction.void(transaction.id)
      result.success?.should == false
      result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::CannotBeVoided
    end
  end

  describe "self.void!" do
    it "returns the transaction if successful" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      returned_transaction = Braintree::Transaction.void!(transaction.id)
      returned_transaction.should == transaction
      returned_transaction.status.should == Braintree::Transaction::Status::Voided
    end

    it "raises a ValidationsFailed if unsuccessful" do
      transaction = Braintree::Transaction.sale(
        :amount => Braintree::Test::TransactionAmounts::Decline,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      ).transaction
      expect do
        Braintree::Transaction.void!(transaction.id)
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "refund" do
    context "partial refunds" do
      it "allows partial refunds" do
        transaction = create_transaction_to_refund
        result = transaction.refund(transaction.amount / 2)
        result.success?.should == true
        result.new_transaction.type.should == "credit"
      end
    end

    it "returns a successful result if successful" do
      transaction = create_transaction_to_refund
      transaction.status.should == Braintree::Transaction::Status::Settled
      result = transaction.refund
      result.success?.should == true
      result.new_transaction.type.should == "credit"
    end

    it "assigns the refund_id on the original transaction" do
      transaction = create_transaction_to_refund
      refund_transaction = transaction.refund.new_transaction
      transaction = Braintree::Transaction.find(transaction.id)

      transaction.refund_id.should == refund_transaction.id
    end

    it "assigns the refunded_transaction_id to the original transaction" do
      transaction = create_transaction_to_refund
      refund_transaction = transaction.refund.new_transaction

      refund_transaction.refunded_transaction_id.should == transaction.id
    end

    it "returns an error if already refunded" do
      transaction = create_transaction_to_refund
      result = transaction.refund
      result.success?.should == true
      result = transaction.refund
      result.success?.should == false
      result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::HasAlreadyBeenRefunded
    end

    it "returns an error result if unsettled" do
      transaction = Braintree::Transaction.create!(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      result = transaction.refund
      result.success?.should == false
      result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::CannotRefundUnlessSettled
    end
  end

  describe "submit_for_settlement" do
    it "returns a successful result if successful" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )
      result = transaction.submit_for_settlement
      result.success?.should == true
    end

    it "can submit a specific amount for settlement" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )
      transaction.amount.should == BigDecimal("1000.00")
      result = transaction.submit_for_settlement("999.99")
      result.success?.should == true
      transaction.amount.should == BigDecimal("999.99")
    end

    it "updates the transaction attributes" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )
      transaction.amount.should == BigDecimal("1000.00")
      result = transaction.submit_for_settlement("999.99")
      result.success?.should == true
      transaction.amount.should == BigDecimal("999.99")
      transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
      transaction.updated_at.between?(Time.now - 60, Time.now).should == true
    end

    it "returns an error result if unsuccessful" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )
      transaction.amount.should == BigDecimal("1000.00")
      result = transaction.submit_for_settlement("1000.01")
      result.success?.should == false
      result.errors.for(:transaction).on(:amount)[0].code.should == Braintree::ErrorCodes::Transaction::SettlementAmountIsTooLarge
      result.params[:transaction][:amount].should == "1000.01"
    end
  end

  describe "submit_for_settlement!" do
    it "returns the transaction if successful" do
      original_transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )
      transaction = original_transaction.submit_for_settlement!
      transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
      transaction.id.should == original_transaction.id
    end

    it "raises a ValidationsFailed if unsuccessful" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "06/2009"
        }
      )
      transaction.amount.should == BigDecimal("1000.00")
      expect do
        transaction.submit_for_settlement!("1000.01")
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "status_history" do
    it "returns an array of StatusDetail" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      transaction.submit_for_settlement!
      transaction.status_history.size.should == 2
      transaction.status_history[0].status.should == Braintree::Transaction::Status::Authorized
      transaction.status_history[1].status.should == Braintree::Transaction::Status::SubmittedForSettlement
    end
  end

  describe "authorization_adjustments" do
    it "includes authorization adjustments on found transactions" do
      found_transaction = Braintree::Transaction.find("authadjustmenttransaction")

      found_transaction.authorization_adjustments.count.should == 1

      authorization_adjustment = found_transaction.authorization_adjustments.first
      authorization_adjustment.amount.should == "-20.00"
      authorization_adjustment.success.should == true
      authorization_adjustment.timestamp.should be_a Time
      authorization_adjustment.processor_response_code.should == "1000"
      authorization_adjustment.processor_response_text.should == "Approved"
    end

    it "includes authorization adjustments soft declined on found transactions" do
      found_transaction = Braintree::Transaction.find("authadjustmenttransactionsoftdeclined")

      found_transaction.authorization_adjustments.count.should == 1

      authorization_adjustment = found_transaction.authorization_adjustments.first
      authorization_adjustment.amount.should == "-20.00"
      authorization_adjustment.success.should == false
      authorization_adjustment.timestamp.should be_a Time
      authorization_adjustment.processor_response_code.should == "3000"
      authorization_adjustment.processor_response_text.should == "Processor Network Unavailable - Try Again"
      authorization_adjustment.processor_response_type.should == Braintree::ProcessorResponseTypes::SoftDeclined
    end

    it "includes authorization adjustments hard declined on found transactions" do
      found_transaction = Braintree::Transaction.find("authadjustmenttransactionharddeclined")

      found_transaction.authorization_adjustments.count.should == 1

      authorization_adjustment = found_transaction.authorization_adjustments.first
      authorization_adjustment.amount.should == "-20.00"
      authorization_adjustment.success.should == false
      authorization_adjustment.timestamp.should be_a Time
      authorization_adjustment.processor_response_code.should == "2015"
      authorization_adjustment.processor_response_text.should == "Transaction Not Allowed"
      authorization_adjustment.processor_response_type.should == Braintree::ProcessorResponseTypes::HardDeclined
    end
  end

  describe "vault_credit_card" do
    it "returns the Braintree::CreditCard if the transaction credit card is stored in the vault" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )
      transaction = customer.credit_cards[0].sale(:amount => "100.00").transaction
      transaction.vault_credit_card.should == customer.credit_cards[0]
    end

    it "returns nil if the transaction credit card is not stored in the vault" do
      transaction = Braintree::Transaction.create!(
        :amount => "100.00",
        :type => "sale",
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )
      transaction.vault_credit_card.should == nil
    end
  end

  describe "vault_customer" do
    it "returns the Braintree::Customer if the transaction customer is stored in the vault" do
      customer = Braintree::Customer.create!(
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )
      transaction = customer.credit_cards[0].sale(:amount => "100.00").transaction
      transaction.vault_customer.should == customer
    end

    it "returns nil if the transaction customer is not stored in the vault" do
      transaction = Braintree::Transaction.create!(
        :amount => "100.00",
        :type => "sale",
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010"
        }
      )
      transaction.vault_customer.should == nil
    end
  end

  describe "void" do
    it "returns a successful result if successful" do
      result = Braintree::Transaction.create(
        :type => "sale",
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      result.success?.should == true
      transaction = result.transaction
      transaction.status.should == Braintree::Transaction::Status::Authorized
      void_result = transaction.void
      void_result.success?.should == true
      void_result.transaction.should == transaction
      transaction.status.should == void_result.transaction.status
    end

    it "returns an error result if unsuccessful" do
      transaction = Braintree::Transaction.sale(
        :amount => Braintree::Test::TransactionAmounts::Decline,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      ).transaction
      transaction.status.should == Braintree::Transaction::Status::ProcessorDeclined
      result = transaction.void
      result.success?.should == false
      result.errors.for(:transaction).on(:base)[0].code.should == Braintree::ErrorCodes::Transaction::CannotBeVoided
    end
  end

  describe "void!" do
    it "returns the transaction if successful" do
      transaction = Braintree::Transaction.sale!(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      )
      transaction.void!.should == transaction
      transaction.status.should == Braintree::Transaction::Status::Voided
    end

    it "raises a ValidationsFailed if unsuccessful" do
      transaction = Braintree::Transaction.sale(
        :amount => Braintree::Test::TransactionAmounts::Decline,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        }
      ).transaction
      transaction.status.should == Braintree::Transaction::Status::ProcessorDeclined
      expect do
        transaction.void!
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  def create_transaction_to_refund
    transaction = Braintree::Transaction.sale!(
      :amount => Braintree::Test::TransactionAmounts::Authorize,
      :credit_card => {
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2009"
      },
      :options => {
        :submit_for_settlement => true
      }
    )

    config = Braintree::Configuration.instantiate
    response = config.http.put("#{config.base_merchant_path}/transactions/#{transaction.id}/settle")
    Braintree::Transaction.find(transaction.id)
  end

  def create_paypal_transaction_for_refund
    transaction = Braintree::Transaction.sale!(
      :amount => Braintree::Test::TransactionAmounts::Authorize,
      :payment_method_nonce => Braintree::Test::Nonce::PayPalOneTimePayment,
      :options => {
        :submit_for_settlement => true
      }
    )

    config = Braintree::Configuration.instantiate
    config.http.put("#{config.base_merchant_path}/transactions/#{transaction.id}/settle")
    Braintree::Transaction.find(transaction.id)
  end

  def create_escrowed_transcation
    transaction = Braintree::Transaction.sale!(
      :amount => Braintree::Test::TransactionAmounts::Authorize,
      :merchant_account_id => SpecHelper::NonDefaultSubMerchantAccountId,
      :credit_card => {
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2009"
      },
      :service_fee_amount => '1.00',
      :options => { :hold_in_escrow => true }
    )

    config = Braintree::Configuration.instantiate
    response = config.http.put("#{config.base_merchant_path}/transactions/#{transaction.id}/settle")
    response = config.http.put("#{config.base_merchant_path}/transactions/#{transaction.id}/escrow")
    Braintree::Transaction.find(transaction.id)
  end

  context "venmo sdk" do
    describe "venmo_sdk_payment_method_code" do
      it "can create a transaction with venmo_sdk_payment_method_code" do
        result = Braintree::Transaction.sale(
          :amount => "10.00",
          :venmo_sdk_payment_method_code => Braintree::Test::VenmoSDK.generate_test_payment_method_code(Braintree::Test::CreditCardNumbers::Visa)
        )
        result.success?.should == true
        result.transaction.credit_card_details.venmo_sdk?.should == false
      end

      it "errors when an invalid payment method code is passed" do
        result = Braintree::Transaction.sale(
          :amount => "10.00",
          :venmo_sdk_payment_method_code => Braintree::Test::VenmoSDK::InvalidPaymentMethodCode
        )
        result.success?.should == false
        result.message.should include("Invalid VenmoSDK payment method code")
        result.errors.map(&:code).should include("91727")
      end
    end

    describe "venmo_sdk_session" do
      it "can create a transaction and vault a card when a venmo_sdk_session is present" do
        result = Braintree::Transaction.sale(
          :amount => "10.00",
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          },
          :options => {
            :venmo_sdk_session => Braintree::Test::VenmoSDK::Session
          }
        )
        result.success?.should == true
        result.transaction.credit_card_details.venmo_sdk?.should == false
      end

      it "venmo_sdk boolean is false when an invalid session is passed" do
        result = Braintree::Transaction.sale(
          :amount => "10.00",
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "05/2009"
          },
          :options => {
            :venmo_sdk_session => Braintree::Test::VenmoSDK::InvalidSession
          }
        )
        result.success?.should == true
        result.transaction.credit_card_details.venmo_sdk?.should == false
      end
    end
  end

  context "paypal" do
    it "can create a transaction for a paypal account" do
      result = Braintree::Transaction.sale(
        :amount => "10.00",
        :payment_method_nonce => Braintree::Test::Nonce::PayPalFuturePayment
      )
      result.success?.should == true
      result.transaction.paypal_details.payer_email.should == "payer@example.com"
      result.transaction.paypal_details.payment_id.should match(/PAY-\w+/)
      result.transaction.paypal_details.authorization_id.should match(/AUTH-\w+/)
      result.transaction.paypal_details.image_url.should_not be_nil
    end

    it "can vault a paypal account on a transaction" do
      result = Braintree::Transaction.sale(
        :amount => "10.00",
        :payment_method_nonce => Braintree::Test::Nonce::PayPalFuturePayment,
        :options => {
          :store_in_vault => true
        }
      )
      result.success?.should == true
      result.transaction.paypal_details.token.should_not be_nil
      result.transaction.paypal_details.payer_email.should == "payer@example.com"
      result.transaction.paypal_details.payment_id.should match(/PAY-\w+/)
      result.transaction.paypal_details.authorization_id.should match(/AUTH-\w+/)
    end

    it "can create a transaction from a vaulted paypal account" do
      customer = Braintree::Customer.create!
      result = Braintree::PaymentMethod.create(
        :payment_method_nonce => Braintree::Test::Nonce::PayPalFuturePayment,
        :customer_id => customer.id
      )

      result.should be_success
      result.payment_method.should be_a(Braintree::PayPalAccount)
      payment_method_token = result.payment_method.token

      result = Braintree::Transaction.sale(
        :amount => "100",
        :customer_id => customer.id,
        :payment_method_token => payment_method_token
      )

      result.should be_success
      result.transaction.paypal_details.token.should == payment_method_token
      result.transaction.paypal_details.payer_email.should == "payer@example.com"
      result.transaction.paypal_details.payment_id.should match(/PAY-\w+/)
      result.transaction.paypal_details.authorization_id.should match(/AUTH-\w+/)
    end

    context "validation failure" do
      it "returns a validation error if consent code and access token are omitted" do
        nonce = nonce_for_paypal_account(:token => "TOKEN")
        result = Braintree::Transaction.sale(
          :amount => "10.00",
          :payment_method_nonce => nonce
        )
        result.should_not be_success
        result.errors.for(:transaction).for(:paypal_account).first.code.should == Braintree::ErrorCodes::PayPalAccount::IncompletePayPalAccount
      end
    end
  end

  context "shared payment method" do
    before(:each) do
      @partner_merchant_gateway = Braintree::Gateway.new(
        :merchant_id => "integration_merchant_public_id",
        :public_key => "oauth_app_partner_user_public_key",
        :private_key => "oauth_app_partner_user_private_key",
        :environment => Braintree::Configuration.environment,
        :logger => Logger.new("/dev/null")
      )
      @customer = @partner_merchant_gateway.customer.create(
        :first_name => "Joe",
        :last_name => "Brown",
        :company => "ExampleCo",
        :email => "joe@example.com",
        :phone => "312.555.1234",
        :fax => "614.555.5678",
        :website => "www.example.com"
      ).customer
      @address = @partner_merchant_gateway.address.create(
        :customer_id => @customer.id,
        :first_name => "Testy",
        :last_name => "McTesterson"
      ).address
      @credit_card = @partner_merchant_gateway.credit_card.create(
        :customer_id => @customer.id,
        :cardholder_name => "Adam Davis",
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2009",
        :billing_address => {
          :first_name => "Adam",
          :last_name => "Davis",
          :postal_code => "95131"
        }
      ).credit_card

      oauth_gateway = Braintree::Gateway.new(
        :client_id => "client_id$#{Braintree::Configuration.environment}$integration_client_id",
        :client_secret => "client_secret$#{Braintree::Configuration.environment}$integration_client_secret",
        :logger => Logger.new("/dev/null")
      )
      access_token = Braintree::OAuthTestHelper.create_token(oauth_gateway, {
        :merchant_public_id => "integration_merchant_id",
        :scope => "grant_payment_method,shared_vault_transactions"
      }).credentials.access_token

      @granting_gateway = Braintree::Gateway.new(
        :access_token => access_token,
        :logger => Logger.new("/dev/null")
      )

    end

    it "oauth app details are returned on transaction created via nonce granting" do
      grant_result = @granting_gateway.payment_method.grant(@credit_card.token, false)

      result = Braintree::Transaction.sale(
        :payment_method_nonce => grant_result.payment_method_nonce.nonce,
        :amount => Braintree::Test::TransactionAmounts::Authorize
      )
      result.transaction.facilitated_details.merchant_id.should == "integration_merchant_id"
      result.transaction.facilitated_details.merchant_name.should == "14ladders"
      result.transaction.facilitated_details.payment_method_nonce.should == grant_result.payment_method_nonce.nonce
      result.transaction.facilitator_details.should_not == nil
      result.transaction.facilitator_details.oauth_application_client_id.should == "client_id$#{Braintree::Configuration.environment}$integration_client_id"
      result.transaction.facilitator_details.oauth_application_name.should == "PseudoShop"
      result.transaction.billing_details.postal_code == nil
    end

    it "billing postal code is returned on transaction created via nonce granting when specified in the grant request" do
      grant_result = @granting_gateway.payment_method.grant(@credit_card.token, :allow_vaulting => false, :include_billing_postal_code => true)

      result = Braintree::Transaction.sale(
        :payment_method_nonce => grant_result.payment_method_nonce.nonce,
        :amount => Braintree::Test::TransactionAmounts::Authorize
      )

      result.transaction.billing_details.postal_code == "95131"
    end

    it "allows transactions to be created with a shared payment method, customer, billing and shipping addresses" do
      result = @granting_gateway.transaction.sale(
        :shared_payment_method_token => @credit_card.token,
        :shared_customer_id => @customer.id,
        :shared_shipping_address_id => @address.id,
        :shared_billing_address_id => @address.id,
        :amount => Braintree::Test::TransactionAmounts::Authorize
      )
      result.success?.should == true
      result.transaction.shipping_details.first_name.should == @address.first_name
      result.transaction.billing_details.first_name.should == @address.first_name
    end

    it "facilitated details are returned on transaction created via a shared_payment_method_token" do
      result = @granting_gateway.transaction.sale(
        :shared_payment_method_token => @credit_card.token,
        :amount => Braintree::Test::TransactionAmounts::Authorize
      )
      result.transaction.facilitated_details.merchant_id.should == "integration_merchant_id"
      result.transaction.facilitated_details.merchant_name.should == "14ladders"
      result.transaction.facilitated_details.payment_method_nonce.should == nil
      result.transaction.facilitator_details.should_not == nil
      result.transaction.facilitator_details.oauth_application_client_id.should == "client_id$#{Braintree::Configuration.environment}$integration_client_id"
      result.transaction.facilitator_details.oauth_application_name.should == "PseudoShop"
    end

    it "facilitated details are returned on transaction created via a shared_payment_method_nonce" do
      shared_nonce = @partner_merchant_gateway.payment_method_nonce.create(
        @credit_card.token
      ).payment_method_nonce.nonce

      result = @granting_gateway.transaction.sale(
        :shared_payment_method_nonce => shared_nonce,
        :amount => Braintree::Test::TransactionAmounts::Authorize
      )
      result.transaction.facilitated_details.merchant_id.should == "integration_merchant_id"
      result.transaction.facilitated_details.merchant_name.should == "14ladders"
      result.transaction.facilitated_details.payment_method_nonce.should == nil
      result.transaction.facilitator_details.should_not == nil
      result.transaction.facilitator_details.oauth_application_client_id.should == "client_id$#{Braintree::Configuration.environment}$integration_client_id"
      result.transaction.facilitator_details.oauth_application_name.should == "PseudoShop"
    end
  end

  context "paypal here" do
    it "gets the details of an auth/capture transaction" do
      result = Braintree::Transaction.find('paypal_here_auth_capture_id')
      result.payment_instrument_type.should eq(Braintree::PaymentInstrumentType::PayPalHere)
      result.paypal_here_details.should_not be_nil

      details = result.paypal_here_details
      details.authorization_id.should_not be_nil
      details.capture_id.should_not be_nil
      details.invoice_id.should_not be_nil
      details.last_4.should_not be_nil
      details.payment_type.should_not be_nil
      details.transaction_fee_amount.should_not be_nil
      details.transaction_fee_currency_iso_code.should_not be_nil
      details.transaction_initiation_date.should_not be_nil
      details.transaction_updated_date.should_not be_nil
    end

    it "gets the details of a sale transaction" do
      result = Braintree::Transaction.find('paypal_here_sale_id')
      result.paypal_here_details.should_not be_nil

      details = result.paypal_here_details
      details.payment_id.should_not be_nil
    end

    it "gets the details of a refunded sale transaction" do
      result = Braintree::Transaction.find('paypal_here_refund_id')
      result.paypal_here_details.should_not be_nil

      details = result.paypal_here_details
      details.refund_id.should_not be_nil
    end
  end

  describe "card on file network tokenization" do
    it "creates a transaction with a vaulted, tokenized credit card" do
      result = Braintree::Transaction.sale(
        :amount => "112.44",
        :payment_method_token => "network_tokenized_credit_card",
      )
      result.success?.should == true
      transaction = result.transaction

      transaction.amount.should == BigDecimal("112.44")
      transaction.processed_with_network_token?.should == true
    end

    it "creates a transaction with a vaulted, non-tokenized credit card" do
      customer = Braintree::Customer.create!
      result = Braintree::PaymentMethod.create(
        :payment_method_nonce => Braintree::Test::Nonce::TransactableVisa,
        :customer_id => customer.id
      )
      payment_method_token = result.payment_method.token

      result = Braintree::Transaction.sale(
        :amount => "112.44",
        :payment_method_token => payment_method_token,
      )
      result.success?.should == true
      transaction = result.transaction

      transaction.amount.should == BigDecimal("112.44")
      transaction.processed_with_network_token?.should == false
    end
  end
end
