require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require File.expand_path(File.dirname(__FILE__) + "/client_api/spec_helper")

describe Braintree::UsBankAccountVerification do
  let(:nonce) { generate_non_plaid_us_bank_account_nonce }
  let(:customer) do
    params = {
      :first_name => "Tom",
      :last_name => "Smith",
      :email => "tom.smith@example.com",
    }

    Braintree::Customer.create(params).customer
  end

  describe "self.confirm_micro_transfer_amounts" do
    before do
      Braintree::Configuration.merchant_id = "integration2_merchant_id"
      Braintree::Configuration.public_key = "integration2_public_key"
      Braintree::Configuration.private_key = "integration2_private_key"
    end

    after(:all) do
      Braintree::Configuration.merchant_id = "integration_merchant_id"
      Braintree::Configuration.public_key = "integration_public_key"
      Braintree::Configuration.private_key = "integration_private_key"
    end

    context "with a micro transfer verification" do
      it "successfully confirms settled amounts" do
        nonce = generate_non_plaid_us_bank_account_nonce("1000000000")

        result = Braintree::PaymentMethod.create(
          :payment_method_nonce => nonce,
          :customer_id => customer.id,
          :options => {
            :verification_merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
            :us_bank_account_verification_method => Braintree::UsBankAccountVerification::VerificationMethod::MicroTransfers,
          }
        )

        result.should be_success

        verification = result.payment_method.verifications.first
        verification.verification_method.should == Braintree::UsBankAccountVerification::VerificationMethod::MicroTransfers
        verification.status.should == Braintree::UsBankAccountVerification::Status::Pending

        response = Braintree::UsBankAccountVerification.confirm_micro_transfer_amounts(verification.id, [17, 29])

        response.should be_success
        response.us_bank_account_verification.status.should == Braintree::UsBankAccountVerification::Status::Verified

        us_bank_account = Braintree::UsBankAccount.find(response.us_bank_account_verification.us_bank_account[:token])

        us_bank_account.verified.should be_truthy
      end

      it "successfully confirms not-yet-settled amounts" do
        nonce = generate_non_plaid_us_bank_account_nonce("1000000001")

        result = Braintree::PaymentMethod.create(
          :payment_method_nonce => nonce,
          :customer_id => customer.id,
          :options => {
            :verification_merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
            :us_bank_account_verification_method => Braintree::UsBankAccountVerification::VerificationMethod::MicroTransfers,
          }
        )

        result.should be_success

        verification = result.payment_method.verifications.first
        verification.verification_method.should == Braintree::UsBankAccountVerification::VerificationMethod::MicroTransfers
        verification.status.should == Braintree::UsBankAccountVerification::Status::Pending

        response = Braintree::UsBankAccountVerification.confirm_micro_transfer_amounts(verification.id, [17, 29])

        response.should be_success
        response.us_bank_account_verification.status.should == Braintree::UsBankAccountVerification::Status::Pending
      end

      it "attempts to confirm" do
        result = Braintree::PaymentMethod.create(
          :payment_method_nonce => nonce,
          :customer_id => customer.id,
          :options => {
            :verification_merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
            :us_bank_account_verification_method => Braintree::UsBankAccountVerification::VerificationMethod::MicroTransfers,
          }
        )

        result.should be_success

        verification = result.payment_method.verifications.first
        verification.verification_method.should == Braintree::UsBankAccountVerification::VerificationMethod::MicroTransfers
        verification.status.should == Braintree::UsBankAccountVerification::Status::Pending

        response = Braintree::UsBankAccountVerification.confirm_micro_transfer_amounts(verification.id, [1, 1])

        response.should_not be_success
        response.errors.for(:us_bank_account_verification)[0].code.should == Braintree::ErrorCodes::UsBankAccountVerification::AmountsDoNotMatch
      end

      it "exceeds the confirmation attempt threshold" do
        result = Braintree::PaymentMethod.create(
          :payment_method_nonce => nonce,
          :customer_id => customer.id,
          :options => {
            :verification_merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
            :us_bank_account_verification_method => Braintree::UsBankAccountVerification::VerificationMethod::MicroTransfers,
          }
        )

        result.should be_success

        verification = result.payment_method.verifications.first

        response = nil
        4.times do
          response = Braintree::UsBankAccountVerification.confirm_micro_transfer_amounts(verification.id, [1, 1])

          response.should_not be_success
          response.errors.for(:us_bank_account_verification)[0].code.should == Braintree::ErrorCodes::UsBankAccountVerification::AmountsDoNotMatch
        end

        response = Braintree::UsBankAccountVerification.confirm_micro_transfer_amounts(verification.id, [1, 1])
        response.should_not be_success
        response.errors.for(:us_bank_account_verification)[0].code.should == Braintree::ErrorCodes::UsBankAccountVerification::TooManyConfirmationAttempts

        response = Braintree::UsBankAccountVerification.confirm_micro_transfer_amounts(verification.id, [1, 1])
        response.should_not be_success
        response.errors.for(:us_bank_account_verification)[0].code.should == Braintree::ErrorCodes::UsBankAccountVerification::TooManyConfirmationAttempts
      end

      it "returns an error for invalid deposit amounts" do
        result = Braintree::PaymentMethod.create(
          :payment_method_nonce => nonce,
          :customer_id => customer.id,
          :options => {
            :verification_merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
            :us_bank_account_verification_method => Braintree::UsBankAccountVerification::VerificationMethod::MicroTransfers,
          }
        )

        result.should be_success

        verification = result.payment_method.verifications.first
        response = Braintree::UsBankAccountVerification.confirm_micro_transfer_amounts(verification.id, ["abc"])

        response.should_not be_success
        response.errors.for(:us_bank_account_verification)[0].code.should == Braintree::ErrorCodes::UsBankAccountVerification::InvalidDepositAmounts
      end
    end

    context "non-micro transfer" do
      it "rejects for incorrect verification type" do
        result = Braintree::PaymentMethod.create(
          :payment_method_nonce => nonce,
          :customer_id => customer.id,
          :options => {
            :verification_merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
            :us_bank_account_verification_method => Braintree::UsBankAccountVerification::VerificationMethod::NetworkCheck,
          }
        )

        result.should be_success

        verification = result.payment_method.verifications.first
        response = Braintree::UsBankAccountVerification.confirm_micro_transfer_amounts(verification.id, [1, 1])

        response.should_not be_success
        response.errors.for(:us_bank_account_verification)[0].code.should == Braintree::ErrorCodes::UsBankAccountVerification::MustBeMicroTransfersVerification
      end
    end
  end

  describe "self.find" do
    it "finds the verification with the given id" do
      result = Braintree::PaymentMethod.create(
        :payment_method_nonce => nonce,
        :customer_id => customer.id,
        :options => {
          :verification_merchant_account_id => SpecHelper::UsBankMerchantAccountId,
          :us_bank_account_verification_method => Braintree::UsBankAccountVerification::VerificationMethod::NetworkCheck,
        }
      )

      result.should be_success

      created_verification = result.payment_method.verifications.first
      found_verification = Braintree::UsBankAccountVerification.find(created_verification.id)

      found_verification.should == created_verification
    end

    it "raises a NotFoundError exception if verification cannot be found" do
      expect do
        Braintree::UsBankAccountVerification.find("invalid-id")
      end.to raise_error(Braintree::NotFoundError, 'verification with id "invalid-id" not found')
    end
  end

  describe "self.search" do
    let(:payment_method) do
      Braintree::PaymentMethod.create(
        :payment_method_nonce => nonce,
        :customer_id => customer.id,
        :options => {
          :verification_merchant_account_id => SpecHelper::UsBankMerchantAccountId,
          :us_bank_account_verification_method => Braintree::UsBankAccountVerification::VerificationMethod::NetworkCheck,
        }
      ).payment_method
    end

    let(:created_verification) do
      payment_method.verifications.first
    end

    it "searches and finds verification using verification fields" do
      found_verifications = Braintree::UsBankAccountVerification.search do |search|
        search.created_at >= (Time.now() - 120)
        search.ids.in created_verification.id
        search.status.in created_verification.status
        search.verification_method.in created_verification.verification_method
      end

      found_verifications.should include(created_verification)
    end

    it "searches and finds verifications using customer fields" do
      found_verifications = Braintree::UsBankAccountVerification.search do |search|
        search.customer_email.is customer.email
        search.customer_id.is customer.id
        search.payment_method_token.is payment_method.token
      end

      found_verifications.count.should eq(1)
    end
  end
end
