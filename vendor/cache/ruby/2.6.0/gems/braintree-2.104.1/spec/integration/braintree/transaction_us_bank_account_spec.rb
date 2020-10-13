require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require File.expand_path(File.dirname(__FILE__) + "/client_api/spec_helper")

describe Braintree::Transaction do
  describe "self.create us bank account" do
    context "compliant merchant" do
      before do
        Braintree::Configuration.merchant_id = "integration2_merchant_id"
        Braintree::Configuration.public_key = "integration2_public_key"
        Braintree::Configuration.private_key = "integration2_private_key"
      end

      context "plaid-verified" do
        let(:plaid_nonce) { generate_valid_plaid_us_bank_account_nonce }

        context "nonce" do
          it "sale succeeds" do
            result = Braintree::Transaction.create(
              :type => "sale",
              :amount => Braintree::Test::TransactionAmounts::Authorize,
              :merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
              :payment_method_nonce => plaid_nonce,
              :options => {
                :submit_for_settlement => true,
              }
            )
            result.success?.should == true
            result.transaction.id.should =~ /^\w{6,}$/
            result.transaction.type.should == "sale"
            result.transaction.payment_instrument_type.should == Braintree::PaymentInstrumentType::UsBankAccount
            result.transaction.amount.should == BigDecimal(Braintree::Test::TransactionAmounts::Authorize)
            result.transaction.status.should == Braintree::Transaction::Status::SettlementPending
            result.transaction.us_bank_account_details.routing_number.should == "011000015"
            result.transaction.us_bank_account_details.last_4.should == "0000"
            result.transaction.us_bank_account_details.account_type.should == "checking"
            result.transaction.us_bank_account_details.account_holder_name.should == "PayPal, Inc."
            result.transaction.us_bank_account_details.bank_name.should == "FEDERAL RESERVE BANK"
            result.transaction.us_bank_account_details.ach_mandate.text.should == "cl mandate text"
            result.transaction.us_bank_account_details.ach_mandate.accepted_at.should be_a Time
          end
        end

        context "token" do
          it "payment_method#create then sale succeeds" do
            payment_method = Braintree::PaymentMethod.create(
              :payment_method_nonce => plaid_nonce,
              :customer_id => Braintree::Customer.create.customer.id,
              :options => {
                :verification_merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
              }
            ).payment_method

            payment_method.verifications.count.should == 1
            payment_method.verifications.first.status.should == Braintree::UsBankAccountVerification::Status::Verified
            payment_method.verifications.first.verification_method.should == Braintree::UsBankAccountVerification::VerificationMethod::TokenizedCheck
            payment_method.verifications.first.id.should_not be_empty
            payment_method.verifications.first.verification_determined_at.should be_a Time
            payment_method.verified.should == true

            result = Braintree::Transaction.create(
              :type => "sale",
              :amount => Braintree::Test::TransactionAmounts::Authorize,
              :merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
              :payment_method_token => payment_method.token,
              :options => {
                :submit_for_settlement => true,
              }
            )

            result.success?.should == true

            transaction = result.transaction

            transaction.id.should =~ /^\w{6,}$/
            transaction.type.should == "sale"
            transaction.amount.should == BigDecimal(Braintree::Test::TransactionAmounts::Authorize)
            transaction.status.should == Braintree::Transaction::Status::SettlementPending
            transaction.us_bank_account_details.routing_number.should == "011000015"
            transaction.us_bank_account_details.last_4.should == "0000"
            transaction.us_bank_account_details.account_type.should == "checking"
            transaction.us_bank_account_details.account_holder_name.should == "PayPal, Inc."
            transaction.us_bank_account_details.bank_name.should == "FEDERAL RESERVE BANK"
            transaction.us_bank_account_details.ach_mandate.text.should == "cl mandate text"
            transaction.us_bank_account_details.ach_mandate.accepted_at.should be_a Time
          end

          it "transaction#create store_in_vault then sale succeeds" do
            result = Braintree::Transaction.create(
              :type => "sale",
              :amount => Braintree::Test::TransactionAmounts::Authorize,
              :merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
              :payment_method_nonce => plaid_nonce,
              :options => {
                :submit_for_settlement => true,
                :store_in_vault => true,
              }
            )

            result.success?.should == true

            result = Braintree::Transaction.create(
              :type => "sale",
              :amount => Braintree::Test::TransactionAmounts::Authorize,
              :merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
              :payment_method_token => result.transaction.us_bank_account_details.token,
              :options => {
                :submit_for_settlement => true,
              }
            )

            result.success?.should == true

            transaction = result.transaction

            transaction.id.should =~ /^\w{6,}$/
            transaction.type.should == "sale"
            transaction.amount.should == BigDecimal(Braintree::Test::TransactionAmounts::Authorize)
            transaction.status.should == Braintree::Transaction::Status::SettlementPending
            transaction.us_bank_account_details.routing_number.should == "011000015"
            transaction.us_bank_account_details.last_4.should == "0000"
            transaction.us_bank_account_details.account_type.should == "checking"
            transaction.us_bank_account_details.account_holder_name.should == "PayPal, Inc."
            transaction.us_bank_account_details.bank_name.should == "FEDERAL RESERVE BANK"
            transaction.us_bank_account_details.ach_mandate.text.should == "cl mandate text"
            transaction.us_bank_account_details.ach_mandate.accepted_at.should be_a Time
          end
        end
      end

      context "not plaid-verified" do
        let(:non_plaid_nonce) { generate_non_plaid_us_bank_account_nonce }
        let(:invalid_nonce) { generate_invalid_us_bank_account_nonce }

        context "nonce" do
          it "sale fails for valid nonce" do
            result = Braintree::Transaction.create(
              :type => "sale",
              :amount => Braintree::Test::TransactionAmounts::Authorize,
              :merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
              :payment_method_nonce => non_plaid_nonce,
              :options => {
                :submit_for_settlement => true,
              }
            )
            result.success?.should == false
            result.errors.for(:transaction).on(:payment_method_nonce)[0].code.should == Braintree::ErrorCodes::Transaction::UsBankAccountNonceMustBePlaidVerified
          end

          it "sale fails for invalid nonce" do
            result = Braintree::Transaction.create(
              :type => "sale",
              :amount => Braintree::Test::TransactionAmounts::Authorize,
              :merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
              :payment_method_nonce => invalid_nonce,
              :options => {
                :submit_for_settlement => true,
              }
            )
            result.success?.should == false
            result.errors.for(:transaction).on(:payment_method_nonce)[0].code.should == Braintree::ErrorCodes::Transaction::PaymentMethodNonceUnknown
          end
        end

        context "token" do
          it "sale succeeds for verified token" do
            result = Braintree::PaymentMethod.create(
              :payment_method_nonce => non_plaid_nonce,
              :customer_id => Braintree::Customer.create.customer.id,
              :options => {
                :us_bank_account_verification_method => "independent_check",
                :verification_merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
              }
            )
            payment_method = result.payment_method

            payment_method.verifications.count.should == 1
            payment_method.verifications.first.status == Braintree::UsBankAccountVerification::Status::Verified
            payment_method.verifications.first.verification_method == Braintree::UsBankAccountVerification::VerificationMethod::IndependentCheck
            payment_method.verifications.first.id.should_not be_empty
            payment_method.verifications.first.verification_determined_at.should be_a Time
            payment_method.verified.should == true

            result = Braintree::Transaction.create(
              :type => "sale",
              :amount => Braintree::Test::TransactionAmounts::Authorize,
              :merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
              :payment_method_token => payment_method.token,
              :options => {
                :submit_for_settlement => true,
              }
            )

            result.success?.should == true
          end

          it "sale fails for unverified token" do
            payment_method = Braintree::PaymentMethod.create(
              :payment_method_nonce => non_plaid_nonce,
              :customer_id => Braintree::Customer.create.customer.id,
              :options => {
                :verification_merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
              }
            ).payment_method

            payment_method.verifications.count.should == 0
            payment_method.verified.should == false

            result = Braintree::Transaction.create(
              :type => "sale",
              :amount => Braintree::Test::TransactionAmounts::Authorize,
              :merchant_account_id => SpecHelper::AnotherUsBankMerchantAccountId,
              :payment_method_token => payment_method.token,
              :options => {
                :submit_for_settlement => true,
              }
            )

            result.success?.should == false
            result.errors.for(:transaction)[0].code.should == Braintree::ErrorCodes::Transaction::UsBankAccountNotVerified
          end
        end
      end
    end

    context "exempt merchant" do
      before do
        Braintree::Configuration.merchant_id = "integration_merchant_id"
        Braintree::Configuration.public_key = "integration_public_key"
        Braintree::Configuration.private_key = "integration_private_key"
      end

      context "plaid-verified" do
        let(:plaid_nonce) { generate_valid_plaid_us_bank_account_nonce }

        context "nonce" do
          it "sale succeeds" do
            result = Braintree::Transaction.create(
              :type => "sale",
              :amount => Braintree::Test::TransactionAmounts::Authorize,
              :merchant_account_id => SpecHelper::UsBankMerchantAccountId,
              :payment_method_nonce => plaid_nonce,
              :options => {
                :submit_for_settlement => true,
              }
            )
            result.success?.should == true
            result.transaction.id.should =~ /^\w{6,}$/
            result.transaction.type.should == "sale"
            result.transaction.payment_instrument_type.should == Braintree::PaymentInstrumentType::UsBankAccount
            result.transaction.amount.should == BigDecimal(Braintree::Test::TransactionAmounts::Authorize)
            result.transaction.status.should == Braintree::Transaction::Status::SettlementPending
            result.transaction.us_bank_account_details.routing_number.should == "011000015"
            result.transaction.us_bank_account_details.last_4.should == "0000"
            result.transaction.us_bank_account_details.account_type.should == "checking"
            result.transaction.us_bank_account_details.account_holder_name.should == "PayPal, Inc."
            result.transaction.us_bank_account_details.bank_name.should == "FEDERAL RESERVE BANK"
            result.transaction.us_bank_account_details.ach_mandate.text.should == "cl mandate text"
            result.transaction.us_bank_account_details.ach_mandate.accepted_at.should be_a Time
          end
        end

        context "token" do
          it "payment_method#create then sale succeeds" do
            result = Braintree::PaymentMethod.create(
              :payment_method_nonce => plaid_nonce,
              :customer_id => Braintree::Customer.create.customer.id,
              :options => {
                :verification_merchant_account_id => SpecHelper::UsBankMerchantAccountId,
              }
            )

            payment_method = result.payment_method

            payment_method.verifications.count.should == 1
            payment_method.verifications.first.status.should == Braintree::UsBankAccountVerification::Status::Verified
            payment_method.verifications.first.verification_method.should == Braintree::UsBankAccountVerification::VerificationMethod::TokenizedCheck
            payment_method.verifications.first.id.should_not be_empty
            payment_method.verifications.first.verification_determined_at.should be_a Time
            payment_method.verified.should == true

            result = Braintree::Transaction.create(
              :type => "sale",
              :amount => Braintree::Test::TransactionAmounts::Authorize,
              :merchant_account_id => SpecHelper::UsBankMerchantAccountId,
              :payment_method_token => payment_method.token,
              :options => {
                :submit_for_settlement => true,
              }
            )

            result.success?.should == true

            transaction = result.transaction

            transaction.id.should =~ /^\w{6,}$/
            transaction.type.should == "sale"
            transaction.amount.should == BigDecimal(Braintree::Test::TransactionAmounts::Authorize)
            transaction.status.should == Braintree::Transaction::Status::SettlementPending
            transaction.us_bank_account_details.routing_number.should == "011000015"
            transaction.us_bank_account_details.last_4.should == "0000"
            transaction.us_bank_account_details.account_type.should == "checking"
            transaction.us_bank_account_details.account_holder_name.should == "PayPal, Inc."
            transaction.us_bank_account_details.bank_name.should == "FEDERAL RESERVE BANK"
            transaction.us_bank_account_details.ach_mandate.text.should == "cl mandate text"
            transaction.us_bank_account_details.ach_mandate.accepted_at.should be_a Time
          end

          it "transaction#create store_in_vault then sale succeeds" do
            result = Braintree::Transaction.create(
              :type => "sale",
              :amount => Braintree::Test::TransactionAmounts::Authorize,
              :merchant_account_id => SpecHelper::UsBankMerchantAccountId,
              :payment_method_nonce => plaid_nonce,
              :options => {
                :submit_for_settlement => true,
                :store_in_vault => true,
              }
            )

            result.success?.should == true

            result = Braintree::Transaction.create(
              :type => "sale",
              :amount => Braintree::Test::TransactionAmounts::Authorize,
              :merchant_account_id => SpecHelper::UsBankMerchantAccountId,
              :payment_method_token => result.transaction.us_bank_account_details.token,
              :options => {
                :submit_for_settlement => true,
              }
            )

            result.success?.should == true

            transaction = result.transaction

            transaction.id.should =~ /^\w{6,}$/
            transaction.type.should == "sale"
            transaction.amount.should == BigDecimal(Braintree::Test::TransactionAmounts::Authorize)
            transaction.status.should == Braintree::Transaction::Status::SettlementPending
            transaction.us_bank_account_details.routing_number.should == "011000015"
            transaction.us_bank_account_details.last_4.should == "0000"
            transaction.us_bank_account_details.account_type.should == "checking"
            transaction.us_bank_account_details.account_holder_name.should == "PayPal, Inc."
            transaction.us_bank_account_details.bank_name.should == "FEDERAL RESERVE BANK"
            transaction.us_bank_account_details.ach_mandate.text.should == "cl mandate text"
            transaction.us_bank_account_details.ach_mandate.accepted_at.should be_a Time
          end
        end
      end

      context "not plaid-verified" do
        let(:non_plaid_nonce) { generate_non_plaid_us_bank_account_nonce }
        let(:invalid_nonce) { generate_invalid_us_bank_account_nonce }

        context "nonce" do
          it "sale succeeds for valid nonce" do
            result = Braintree::Transaction.create(
              :type => "sale",
              :amount => Braintree::Test::TransactionAmounts::Authorize,
              :merchant_account_id => SpecHelper::UsBankMerchantAccountId,
              :payment_method_nonce => non_plaid_nonce,
              :options => {
                :submit_for_settlement => true,
              }
            )
            result.success?.should == true

            transaction = result.transaction

            transaction.id.should =~ /^\w{6,}$/
            transaction.type.should == "sale"
            transaction.amount.should == BigDecimal(Braintree::Test::TransactionAmounts::Authorize)
            transaction.status.should == Braintree::Transaction::Status::SettlementPending
            transaction.us_bank_account_details.routing_number.should == "021000021"
            transaction.us_bank_account_details.last_4.should == "0000"
            transaction.us_bank_account_details.account_type.should == "checking"
            transaction.us_bank_account_details.account_holder_name.should == "John Doe"
            transaction.us_bank_account_details.bank_name.should =~ /CHASE/
            transaction.us_bank_account_details.ach_mandate.text.should == "cl mandate text"
            transaction.us_bank_account_details.ach_mandate.accepted_at.should be_a Time
          end

          it "sale fails for invalid nonce" do
            result = Braintree::Transaction.create(
              :type => "sale",
              :amount => Braintree::Test::TransactionAmounts::Authorize,
              :merchant_account_id => SpecHelper::UsBankMerchantAccountId,
              :payment_method_nonce => invalid_nonce,
              :options => {
                :submit_for_settlement => true,
              }
            )
            result.success?.should == false
            result.errors.for(:transaction).on(:payment_method_nonce)[0].code.should == Braintree::ErrorCodes::Transaction::PaymentMethodNonceUnknown
          end
        end

        context "token" do
          it "sale succeeds for unverified token" do
            result = Braintree::PaymentMethod.create(
              :payment_method_nonce => non_plaid_nonce,
              :customer_id => Braintree::Customer.create.customer.id,
              :options => {
                :verification_merchant_account_id => SpecHelper::UsBankMerchantAccountId,
              }
            )
            payment_method = result.payment_method

            payment_method.verifications.count.should == 1
            payment_method.verifications.first.status == Braintree::UsBankAccountVerification::Status::Verified
            payment_method.verifications.first.verification_method == Braintree::UsBankAccountVerification::VerificationMethod::IndependentCheck
            payment_method.verifications.first.id.should_not be_empty
            payment_method.verifications.first.verification_determined_at.should be_a Time
            payment_method.verified.should == true

            result = Braintree::Transaction.create(
              :type => "sale",
              :amount => Braintree::Test::TransactionAmounts::Authorize,
              :merchant_account_id => SpecHelper::UsBankMerchantAccountId,
              :payment_method_token => payment_method.token,
              :options => {
                :submit_for_settlement => true,
              }
            )

            result.success?.should == true
          end
        end
      end
    end
  end
end
