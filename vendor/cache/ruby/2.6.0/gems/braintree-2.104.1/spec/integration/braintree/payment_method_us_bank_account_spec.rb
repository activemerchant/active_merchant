require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require File.expand_path(File.dirname(__FILE__) + "/client_api/spec_helper")

describe Braintree::PaymentMethod do
  describe "self.create" do
    context "compliant merchant" do
      before do
        Braintree::Configuration.merchant_id = "integration2_merchant_id"
        Braintree::Configuration.public_key = "integration2_public_key"
        Braintree::Configuration.private_key = "integration2_private_key"
      end

      context "plaid verified nonce" do
        let(:nonce) { generate_valid_plaid_us_bank_account_nonce }

        it "succeeds" do
          customer = Braintree::Customer.create.customer
          result = Braintree::PaymentMethod.create(
            :payment_method_nonce => nonce,
            :customer_id => customer.id,
            :options => {
              :verification_merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
            }
          )

          result.should be_success
          us_bank_account = result.payment_method
          us_bank_account.should be_a(Braintree::UsBankAccount)
          us_bank_account.routing_number.should == "011000015"
          us_bank_account.last_4.should == "0000"
          us_bank_account.account_type.should == "checking"
          us_bank_account.account_holder_name.should == "PayPal, Inc."
          us_bank_account.bank_name.should == "FEDERAL RESERVE BANK"
          us_bank_account.default.should == true
          us_bank_account.ach_mandate.text.should == "cl mandate text"
          us_bank_account.ach_mandate.accepted_at.should be_a Time

          us_bank_account.verifications.count.should == 1
          us_bank_account.verifications.first.status.should == Braintree::UsBankAccountVerification::Status::Verified
          us_bank_account.verifications.first.verification_method.should == Braintree::UsBankAccountVerification::VerificationMethod::TokenizedCheck
          us_bank_account.verifications.first.id.should_not be_empty
          us_bank_account.verifications.first.verification_determined_at.should be_a Time
          us_bank_account.verified.should == true

          Braintree::PaymentMethod.find(us_bank_account.token).should be_a(Braintree::UsBankAccount)
        end

        [
          Braintree::UsBankAccountVerification::VerificationMethod::IndependentCheck,
          Braintree::UsBankAccountVerification::VerificationMethod::NetworkCheck,
        ].each do |method|
          it "succeeds and verifies via #{method}" do
            customer = Braintree::Customer.create.customer
            result = Braintree::PaymentMethod.create(
              :payment_method_nonce => nonce,
              :customer_id => customer.id,
              :options => {
                :us_bank_account_verification_method => method,
                :verification_merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
              }
            )

            result.should be_success
            us_bank_account = result.payment_method
            us_bank_account.should be_a(Braintree::UsBankAccount)
            us_bank_account.routing_number.should == "011000015"
            us_bank_account.last_4.should == "0000"
            us_bank_account.account_type.should == "checking"
            us_bank_account.account_holder_name.should == "PayPal, Inc."
            us_bank_account.bank_name.should == "FEDERAL RESERVE BANK"
            us_bank_account.default.should == true
            us_bank_account.ach_mandate.text.should == "cl mandate text"
            us_bank_account.ach_mandate.accepted_at.should be_a Time
            us_bank_account.verified.should == true

            us_bank_account.verifications.count.should == 2

            us_bank_account.verifications.map(&:verification_method).should contain_exactly(
              Braintree::UsBankAccountVerification::VerificationMethod::TokenizedCheck,
              method,
            )

            us_bank_account.verifications.each do |verification|
              verification.status.should == Braintree::UsBankAccountVerification::Status::Verified
              verification.id.should_not be_empty
              verification.verification_determined_at.should be_a Time
            end

            Braintree::PaymentMethod.find(us_bank_account.token).should be_a(Braintree::UsBankAccount)
          end
        end
      end

      context "non plaid verified nonce" do
        let(:nonce) { generate_non_plaid_us_bank_account_nonce }

        it "succeeds and does not verify when no method provided" do
          customer = Braintree::Customer.create.customer
          result = Braintree::PaymentMethod.create(
            :payment_method_nonce => nonce,
            :customer_id => customer.id,
            :options => {
              :verification_merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
            }
          )

          result.should be_success
          us_bank_account = result.payment_method
          us_bank_account.should be_a(Braintree::UsBankAccount)
          us_bank_account.routing_number.should == "021000021"
          us_bank_account.last_4.should == "0000"
          us_bank_account.account_type.should == "checking"
          us_bank_account.account_holder_name.should == "John Doe"
          us_bank_account.bank_name.should =~ /CHASE/
          us_bank_account.default.should == true
          us_bank_account.ach_mandate.text.should == "cl mandate text"
          us_bank_account.ach_mandate.accepted_at.should be_a Time

          us_bank_account.verifications.count.should == 0
          us_bank_account.verified.should == false

          Braintree::PaymentMethod.find(us_bank_account.token).should be_a(Braintree::UsBankAccount)
        end

        [
          Braintree::UsBankAccountVerification::VerificationMethod::IndependentCheck,
          Braintree::UsBankAccountVerification::VerificationMethod::NetworkCheck,
        ].each do |method|
          it "succeeds and verifies via #{method}" do
            customer = Braintree::Customer.create.customer
            result = Braintree::PaymentMethod.create(
              :payment_method_nonce => nonce,
              :customer_id => customer.id,
              :options => {
                :us_bank_account_verification_method => method,
                :verification_merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
              }
            )

            result.should be_success
            us_bank_account = result.payment_method
            us_bank_account.should be_a(Braintree::UsBankAccount)
            us_bank_account.routing_number.should == "021000021"
            us_bank_account.last_4.should == "0000"
            us_bank_account.account_type.should == "checking"
            us_bank_account.account_holder_name.should == "John Doe"
            us_bank_account.bank_name.should =~ /CHASE/
            us_bank_account.default.should == true
            us_bank_account.ach_mandate.text.should == "cl mandate text"
            us_bank_account.ach_mandate.accepted_at.should be_a Time

            us_bank_account.verifications.count.should == 1
            us_bank_account.verifications.first.status.should == Braintree::UsBankAccountVerification::Status::Verified
            us_bank_account.verifications.first.verification_method.should == method
            us_bank_account.verifications.first.id.should_not be_empty
            us_bank_account.verifications.first.verification_determined_at.should be_a Time
            us_bank_account.verified.should == true

            Braintree::PaymentMethod.find(us_bank_account.token).should be_a(Braintree::UsBankAccount)
          end
        end
      end

      it "fails with invalid nonce" do
        customer = Braintree::Customer.create.customer
        result = Braintree::PaymentMethod.create(
          :payment_method_nonce => generate_invalid_us_bank_account_nonce,
          :customer_id => customer.id
        )

        result.should_not be_success
        result.errors.for(:payment_method).on(:payment_method_nonce)[0].code.should == Braintree::ErrorCodes::PaymentMethod::PaymentMethodNonceUnknown
      end
    end

    context "exempt merchant" do
      context "plaid verified nonce" do
        before do
          Braintree::Configuration.merchant_id = "integration_merchant_id"
          Braintree::Configuration.public_key = "integration_public_key"
          Braintree::Configuration.private_key = "integration_private_key"
        end

        let(:nonce) { generate_valid_plaid_us_bank_account_nonce }

        it "succeeds and verifies via independent check" do
          customer = Braintree::Customer.create.customer
          result = Braintree::PaymentMethod.create(
            :payment_method_nonce => nonce,
            :customer_id => customer.id,
            :options => {
              :verification_merchant_account_id => SpecHelper::UsBankMerchantAccountId,
            }
          )

          result.should be_success
          us_bank_account = result.payment_method
          us_bank_account.should be_a(Braintree::UsBankAccount)
          us_bank_account.routing_number.should == "011000015"
          us_bank_account.last_4.should == "0000"
          us_bank_account.account_type.should == "checking"
          us_bank_account.account_holder_name.should == "PayPal, Inc."
          us_bank_account.bank_name.should == "FEDERAL RESERVE BANK"
          us_bank_account.default.should == true
          us_bank_account.ach_mandate.text.should == "cl mandate text"
          us_bank_account.ach_mandate.accepted_at.should be_a Time

          us_bank_account.verifications.count.should == 1
          us_bank_account.verifications.first.status.should == Braintree::UsBankAccountVerification::Status::Verified
          us_bank_account.verifications.first.verification_method.should == Braintree::UsBankAccountVerification::VerificationMethod::TokenizedCheck
          us_bank_account.verifications.first.id.should_not be_empty
          us_bank_account.verifications.first.verification_determined_at.should be_a Time
          us_bank_account.verified.should == true

          Braintree::PaymentMethod.find(us_bank_account.token).should be_a(Braintree::UsBankAccount)
        end
      end

      context "non plaid verified nonce" do
        let(:nonce) { generate_non_plaid_us_bank_account_nonce }

        it "succeeds and verifies via independent check" do
          customer = Braintree::Customer.create.customer
          result = Braintree::PaymentMethod.create(
            :payment_method_nonce => nonce,
            :customer_id => customer.id,
            :options => {
              :verification_merchant_account_id => SpecHelper::UsBankMerchantAccountId,
            }
          )

          result.should be_success
          us_bank_account = result.payment_method
          us_bank_account.should be_a(Braintree::UsBankAccount)
          us_bank_account.routing_number.should == "021000021"
          us_bank_account.last_4.should == "0000"
          us_bank_account.account_type.should == "checking"
          us_bank_account.account_holder_name.should == "John Doe"
          us_bank_account.bank_name.should =~ /CHASE/
          us_bank_account.default.should == true
          us_bank_account.ach_mandate.text.should == "cl mandate text"
          us_bank_account.ach_mandate.accepted_at.should be_a Time

          us_bank_account.verifications.count.should == 1
          us_bank_account.verifications.first.status.should == Braintree::UsBankAccountVerification::Status::Verified
          us_bank_account.verifications.first.verification_method.should == Braintree::UsBankAccountVerification::VerificationMethod::IndependentCheck
          us_bank_account.verifications.first.id.should_not be_empty
          us_bank_account.verifications.first.verification_determined_at.should be_a Time
          us_bank_account.verified.should == true

          Braintree::PaymentMethod.find(us_bank_account.token).should be_a(Braintree::UsBankAccount)
        end
      end

      it "fails with invalid nonce" do
        customer = Braintree::Customer.create.customer
        result = Braintree::PaymentMethod.create(
          :payment_method_nonce => generate_invalid_us_bank_account_nonce,
          :customer_id => customer.id
        )

        result.should_not be_success
        result.errors.for(:payment_method).on(:payment_method_nonce)[0].code.should == Braintree::ErrorCodes::PaymentMethod::PaymentMethodNonceUnknown
      end
    end
  end

  context "self.update" do
    context "compliant merchant" do
      before do
        Braintree::Configuration.merchant_id = "integration2_merchant_id"
        Braintree::Configuration.public_key = "integration2_public_key"
        Braintree::Configuration.private_key = "integration2_private_key"
      end

      context "unverified token" do
        let(:payment_method) do
          customer = Braintree::Customer.create.customer
          result = Braintree::PaymentMethod.create(
            :payment_method_nonce => generate_non_plaid_us_bank_account_nonce,
            :customer_id => customer.id,
            :options => {
              :verification_merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
            },
          ).payment_method
        end

        [
          Braintree::UsBankAccountVerification::VerificationMethod::IndependentCheck,
          Braintree::UsBankAccountVerification::VerificationMethod::NetworkCheck,
        ].each do |method|
          it "succeeds and verifies via #{method}" do
            result = Braintree::PaymentMethod.update(
              payment_method.token,
              :options => {
                :verification_merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
                :us_bank_account_verification_method => method,
              },
            )

            result.should be_success

            us_bank_account = result.payment_method
            us_bank_account.should be_a(Braintree::UsBankAccount)
            us_bank_account.routing_number.should == "021000021"
            us_bank_account.last_4.should == "0000"
            us_bank_account.account_type.should == "checking"
            us_bank_account.account_holder_name.should == "John Doe"
            us_bank_account.bank_name.should =~ /CHASE/
            us_bank_account.default.should == true
            us_bank_account.ach_mandate.text.should == "cl mandate text"
            us_bank_account.ach_mandate.accepted_at.should be_a Time

            us_bank_account.verifications.count.should == 1
            us_bank_account.verifications.first.status.should == Braintree::UsBankAccountVerification::Status::Verified
            us_bank_account.verifications.first.verification_method.should == method
            us_bank_account.verifications.first.id.should_not be_empty
            us_bank_account.verifications.first.verification_determined_at.should be_a Time
            us_bank_account.verified.should == true

            Braintree::PaymentMethod.find(us_bank_account.token).should be_a(Braintree::UsBankAccount)
          end
        end

        it "fails with invalid verification method" do
          result = Braintree::PaymentMethod.update(
            payment_method.token,
            :options => {
              :verification_merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
              :us_bank_account_verification_method => "blahblah",
            },
          )

          result.should_not be_success
          result.errors.for(:options).first.code.should == Braintree::ErrorCodes::PaymentMethod::Options::UsBankAccountVerificationMethodIsInvalid
        end
      end
    end

    context "exempt merchant" do
      before do
        Braintree::Configuration.merchant_id = "integration_merchant_id"
        Braintree::Configuration.public_key = "integration_public_key"
        Braintree::Configuration.private_key = "integration_private_key"
      end

      context "unverified token" do
        let(:payment_method) do
          customer = Braintree::Customer.create.customer
          result = Braintree::PaymentMethod.create(
            :payment_method_nonce => generate_non_plaid_us_bank_account_nonce,
            :customer_id => customer.id,
            :options => {
              :verification_merchant_account_id => SpecHelper::UsBankMerchantAccountId,
            }
          ).payment_method
        end

        [
          Braintree::UsBankAccountVerification::VerificationMethod::IndependentCheck,
          Braintree::UsBankAccountVerification::VerificationMethod::NetworkCheck,
        ].each do |method|
          it "succeeds and verifies via #{method}" do
            result = Braintree::PaymentMethod.update(
              payment_method.token,
              :options => {
                :verification_merchant_account_id => SpecHelper::UsBankMerchantAccountId,
                :us_bank_account_verification_method => method,
              },
            )

            result.should be_success

            us_bank_account = result.payment_method
            us_bank_account.should be_a(Braintree::UsBankAccount)
            us_bank_account.routing_number.should == "021000021"
            us_bank_account.last_4.should == "0000"
            us_bank_account.account_type.should == "checking"
            us_bank_account.account_holder_name.should == "John Doe"
            us_bank_account.bank_name.should =~ /CHASE/
            us_bank_account.default.should == true
            us_bank_account.ach_mandate.text.should == "cl mandate text"
            us_bank_account.ach_mandate.accepted_at.should be_a Time

            us_bank_account.verifications.count.should == 2
            verification = us_bank_account.verifications.find do |verification|
              verification.verification_method == method
            end
            verification.status.should == Braintree::UsBankAccountVerification::Status::Verified
            verification.id.should_not be_empty
            verification.verification_determined_at.should be_a Time
            us_bank_account.verified.should == true

            Braintree::PaymentMethod.find(us_bank_account.token).should be_a(Braintree::UsBankAccount)
          end
        end

        it "fails with invalid verification method" do
          result = Braintree::PaymentMethod.update(
            payment_method.token,
            :options => {
              :us_bank_account_verification_method => "blahblah",
            },
          )

          result.should_not be_success
          result.errors.for(:options).first.code.should == Braintree::ErrorCodes::PaymentMethod::Options::UsBankAccountVerificationMethodIsInvalid
        end
      end
    end
  end
end
