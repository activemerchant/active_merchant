require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::CreditCardVerification, "search" do

  describe "self.create" do
    it "creates a new verification" do
      verification_params = {
        :credit_card => {
          :expiration_date => "05/2012",
          :number => Braintree::Test::CreditCardNumbers::Visa,
        },
        :options => {
          :amount => "10.00"
        }
      }

      result = Braintree::CreditCardVerification.create(verification_params)

      result.should be_success
      result.credit_card_verification.id.should =~ /^\w{6,}$/
      result.credit_card_verification.status.should == Braintree::CreditCardVerification::Status::Verified
      result.credit_card_verification.processor_response_code.should == "1000"
      result.credit_card_verification.processor_response_text.should == "Approved"
      result.credit_card_verification.processor_response_type.should == Braintree::ProcessorResponseTypes::Approved
      expect(result.credit_card_verification.network_transaction_id).not_to be_nil
    end

    it "creates a new verification with network response code/text" do
      verification_params = {
        :credit_card => {
          :expiration_date => "05/2012",
          :number => Braintree::Test::CreditCardNumbers::Visa,
        },
        :options => {
          :amount => "10.00"
        }
      }

      result = Braintree::CreditCardVerification.create(verification_params)

      expect(result).to be_success
      expect(result.credit_card_verification.status).to eq(Braintree::CreditCardVerification::Status::Verified)
      expect(result.credit_card_verification.processor_response_code).to eq("1000")
      expect(result.credit_card_verification.processor_response_text).to eq("Approved")
      expect(result.credit_card_verification.network_response_code).to eq("XX")
      expect(result.credit_card_verification.network_response_text).to eq("sample network response text")
      expect(result.credit_card_verification.processor_response_type).to eq(Braintree::ProcessorResponseTypes::Approved)
    end

    it "returns processor response code and text as well as the additional processor response if declined" do
      verification_params = {
        :credit_card => {
          :expiration_date => "05/2012",
          :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
        },
        :options => {
          :amount => "10.00"
        }
      }

      result = Braintree::CreditCardVerification.create(verification_params)

      result.success?.should == false
      result.credit_card_verification.id.should =~ /^\w{6,}$/
      result.credit_card_verification.status.should == Braintree::CreditCardVerification::Status::ProcessorDeclined
      result.credit_card_verification.processor_response_code.should == "2000"
      result.credit_card_verification.processor_response_text.should == "Do Not Honor"
      result.credit_card_verification.processor_response_type.should == Braintree::ProcessorResponseTypes::SoftDeclined
    end

    it "returns validation errors" do
      verification_params = {
        :credit_card => {
          :expiration_date => "05/2012",
          :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
        },
        :options => {
          :amount => "-10.00"
        }
      }

      result = Braintree::CreditCardVerification.create(verification_params)

      result.success?.should == false
      result.errors.for(:verification).for(:options).first.code.should == Braintree::ErrorCodes::Verification::Options::AmountCannotBeNegative
    end

    it "returns account type with debit" do
      result = Braintree::CreditCardVerification.create(
        :credit_card => {
          :expiration_date => "01/2020",
          :number => Braintree::Test::CreditCardNumbers::Hiper
        },
        :options => {
          :merchant_account_id => SpecHelper::HiperBRLMerchantAccountId,
          :account_type => "debit",
        },
      )

      result.success?.should == true
      result.credit_card_verification.credit_card[:account_type].should == "debit"
    end

    it "returns account type with credit" do
      result = Braintree::CreditCardVerification.create(
        :credit_card => {
          :expiration_date => "01/2020",
          :number => Braintree::Test::CreditCardNumbers::Hiper
        },
        :options => {
          :merchant_account_id => SpecHelper::HiperBRLMerchantAccountId,
          :account_type => "credit",
        },
      )

      result.success?.should == true
      result.credit_card_verification.credit_card[:account_type].should == "credit"
    end

    it "errors with unsupported account type" do
      result = Braintree::CreditCardVerification.create(
        :credit_card => {
          :expiration_date => "01/2020",
          :number => Braintree::Test::CreditCardNumbers::Visa
        },
        :options => {
          :account_type => "credit",
        },
      )

      result.success?.should == false
      result.errors.for(:verification).for(:options).on(:account_type)[0].code.should == Braintree::ErrorCodes::Verification::Options::AccountTypeNotSupported
    end

    it "errors with invalid account type" do
      result = Braintree::CreditCardVerification.create(
        :credit_card => {
          :expiration_date => "01/2020",
          :number => Braintree::Test::CreditCardNumbers::Hiper
        },
        :options => {
          :merchant_account_id => SpecHelper::HiperBRLMerchantAccountId,
          :account_type => "ach",
        },
      )

      result.success?.should == false
      result.errors.for(:verification).for(:options).on(:account_type)[0].code.should == Braintree::ErrorCodes::Verification::Options::AccountTypeIsInvalid
    end
  end

  describe "self.find" do
    it "finds the verification with the given id" do
      credit_card_params = {
        :expiration_date => "05/2012",
        :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
        :options => {
          :verify_card => true
        },
      }
      credit_card_verification = Braintree::Customer.create(:credit_card => credit_card_params).credit_card_verification
      found_verification = Braintree::CreditCardVerification.find(credit_card_verification.id)

      found_verification.should == credit_card_verification
      found_verification.graphql_id.should_not be_nil
    end

    it "raises a NotFoundError exception if verification cannot be found" do
      expect do
        Braintree::CreditCardVerification.find("invalid-id")
      end.to raise_error(Braintree::NotFoundError, 'verification with id "invalid-id" not found')
    end
  end

  describe "self.search" do
    before(:each) do
      @customer_params = {
        :first_name => "Tom",
        :last_name => "Smith",
        :email => "tom.smith@example.com",
      }
      @billing_address_params = {
        :postal_code => "90210"
      }
      @credit_card_params = {
        :cardholder_name => "Tom Smith",
        :expiration_date => "05/2012",
        :options => {
          :verify_card => true
        },
        :billing_address => @billing_address_params,
      }

      customer_create_result = Braintree::Customer.create(@customer_params)
      @customer = customer_create_result.customer
    end

    it "searches and finds verification using verification fields" do
      max_seconds_between_create_and_search = 120
      result = Braintree::CreditCard.create(@credit_card_params.merge({
        :customer_id => @customer.id,
        :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
      }))
      credit_card_verification = result.credit_card_verification

      found_verifications = Braintree::CreditCardVerification.search do |search|
        search.billing_address_details_postal_code.is @billing_address_params[:postal_code]
        search.created_at >= (Time.now() - max_seconds_between_create_and_search)
        search.credit_card_card_type.in Braintree::CreditCard::CardType::Visa
        search.credit_card_cardholder_name.is @credit_card_params[:cardholder_name]
        search.credit_card_expiration_date.is @credit_card_params[:expiration_date]
        search.credit_card_number.is @credit_card_params[:number]
        search.ids.in credit_card_verification.id
        search.status.in credit_card_verification.status
      end

      found_verifications.should include(credit_card_verification)
    end

    it "searches and finds verifications using customer fields" do
      result = Braintree::CreditCard.create(@credit_card_params.merge({
        :customer_id => @customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
      }))
      credit_card = result.credit_card

      found_verifications = Braintree::CreditCardVerification.search do |search|
        search.customer_email.is @customer_params[:email]
        search.customer_id.is @customer.id
        search.payment_method_token.is credit_card.token
      end

      found_verifications.count.should eq(1)
    end

    describe "card type indicators" do
      it "returns prepaid on a prepaid card" do
        cardholder_name = "Tom #{rand(1_000_000)} Smith"

        result = Braintree::Customer.create(
          :credit_card => {
          :cardholder_name => cardholder_name,
          :expiration_date => "05/2012",
          :number => Braintree::Test::CreditCardNumbers::CardTypeIndicators::Prepaid,
          :cvv => '200',
          :options => {
            :verify_card => true
        }
        })

        search_results = Braintree::CreditCardVerification.search do |search|
          search.credit_card_cardholder_name.is cardholder_name
        end

        verification_id = search_results.first.id

        found_verification = Braintree::CreditCardVerification.find(verification_id)
        found_verification.credit_card[:prepaid].should == Braintree::CreditCard::Prepaid::Yes
      end
    end
  end
end
