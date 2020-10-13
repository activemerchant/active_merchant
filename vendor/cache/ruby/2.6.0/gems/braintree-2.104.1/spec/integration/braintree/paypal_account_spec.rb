require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require File.expand_path(File.dirname(__FILE__) + "/client_api/spec_helper")

describe Braintree::PayPalAccount do
  describe "self.find" do
    it "returns a PayPalAccount" do
      customer = Braintree::Customer.create!
      payment_method_token = random_payment_method_token

      nonce = nonce_for_paypal_account(
        :consent_code => "consent-code",
        :token => payment_method_token
      )
      result = Braintree::PaymentMethod.create(
        :payment_method_nonce => nonce,
        :customer_id => customer.id
      )
      result.should be_success

      paypal_account = Braintree::PayPalAccount.find(payment_method_token)
      paypal_account.should be_a(Braintree::PayPalAccount)
      paypal_account.token.should == payment_method_token
      paypal_account.email.should == "jane.doe@example.com"
      paypal_account.image_url.should_not be_nil
      paypal_account.created_at.should_not be_nil
      paypal_account.updated_at.should_not be_nil
      paypal_account.customer_id.should == customer.id
      paypal_account.revoked_at.should be_nil
    end

    it "returns a PayPalAccount with a billing agreement id" do
      customer = Braintree::Customer.create!
      payment_method_token = random_payment_method_token

      result = Braintree::PaymentMethod.create(
        :payment_method_nonce => Braintree::Test::Nonce::PayPalBillingAgreement,
        :customer_id => customer.id,
        :token => payment_method_token
      )
      result.should be_success

      paypal_account = Braintree::PayPalAccount.find(payment_method_token)
      paypal_account.billing_agreement_id.should_not be_nil
    end

    it "raises if the payment method token is not found" do
      expect do
        Braintree::PayPalAccount.find("nonexistant-paypal-account")
      end.to raise_error(Braintree::NotFoundError)
    end

    it "does not return a different payment method type" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2009",
        :cvv => "100",
        :token => "CREDIT_CARD_TOKEN"
      )

      expect do
        Braintree::PayPalAccount.find("CREDIT_CARD_TOKEN")
      end.to raise_error(Braintree::NotFoundError)
    end

    it "returns subscriptions associated with a paypal account" do
      customer = Braintree::Customer.create!
      payment_method_token = random_payment_method_token

      nonce = nonce_for_paypal_account(
        :consent_code => "consent-code",
        :token => payment_method_token
      )
      result = Braintree::PaymentMethod.create(
        :payment_method_nonce => nonce,
        :customer_id => customer.id
      )
      result.should be_success

      token = result.payment_method.token

      subscription1 = Braintree::Subscription.create(
        :payment_method_token => token,
        :plan_id => SpecHelper::TriallessPlan[:id]
      ).subscription

      subscription2 = Braintree::Subscription.create(
        :payment_method_token => token,
        :plan_id => SpecHelper::TriallessPlan[:id]
      ).subscription

      paypal_account = Braintree::PayPalAccount.find(token)
      paypal_account.subscriptions.map(&:id).sort.should == [subscription1.id, subscription2.id].sort
    end
  end

  describe "self.create" do
    it "creates a PayPalAccount" do
      customer = Braintree::Customer.create!
      result = Braintree::PayPalAccount.create(
        :customer_id => customer.id,
        :billing_agreement_id => "some_billing_agreement_id",
        :email => "some@example.com",
        :options => {
            :make_default => true,
            :fail_on_duplicate_payment_method => true,
        }
      )

      result.should be_success
      result.paypal_account.billing_agreement_id.should == "some_billing_agreement_id"
      result.paypal_account.email.should == "some@example.com"
    end

    it "throws an error if customer id is not specified" do
      result = Braintree::PayPalAccount.create(
        :billing_agreement_id => "some_billing_agreement_id",
        :email => "some@example.com"
      )

      result.success?.should == false
      result.errors.first.code.should == "82905"
    end

    it "throws an error if billing agreement id is not specified" do
      customer = Braintree::Customer.create!
      result = Braintree::PayPalAccount.create(
        :customer_id => customer.id,
        :email => "some@example.com"
      )

      result.success?.should == false
      result.errors.map(&:code).should include("82902")
    end
  end

  describe "self.update" do
    it "updates a PayPalAccount" do
      customer = Braintree::Customer.create!
      create_result = Braintree::PayPalAccount.create(
        :customer_id => customer.id,
        :billing_agreement_id => "first_billing_agreement_id",
        :email => "first@example.com"
      )
      create_result.success?.should == true

      update_result = Braintree::PayPalAccount.update(
        create_result.paypal_account.token,
        :billing_agreement_id => "second_billing_agreement_id",
        :email => "second@example.com"
      )

      update_result.success?.should == true
      paypal_account = update_result.paypal_account

      paypal_account.billing_agreement_id.should == "second_billing_agreement_id"
      paypal_account.email.should == "second@example.com"
    end

    it "updates a paypal account's token" do
      customer = Braintree::Customer.create!
      original_token = random_payment_method_token
      nonce = nonce_for_paypal_account(
        :consent_code => "consent-code",
        :token => original_token
      )
      original_result = Braintree::PaymentMethod.create(
        :payment_method_nonce => nonce,
        :customer_id => customer.id
      )

      updated_token = "UPDATED_TOKEN-" + rand(36**3).to_s(36)
      updated_result = Braintree::PayPalAccount.update(
        original_token,
        :token => updated_token
      )

      updated_paypal_account = Braintree::PayPalAccount.find(updated_token)
      updated_paypal_account.email.should == original_result.payment_method.email

      expect do
        Braintree::PayPalAccount.find(original_token)
      end.to raise_error(Braintree::NotFoundError, "payment method with token \"#{original_token}\" not found")
    end

    it "can make a paypal account the default payment method" do
      customer = Braintree::Customer.create!
      result = Braintree::CreditCard.create(
        :customer_id => customer.id,
        :number => Braintree::Test::CreditCardNumbers::Visa,
        :expiration_date => "05/2009",
        :options => {:make_default => true}
      )
      result.should be_success

      nonce = nonce_for_paypal_account(:consent_code => "consent-code")
      original_token = Braintree::PaymentMethod.create(
        :payment_method_nonce => nonce,
        :customer_id => customer.id
      ).payment_method.token

      updated_result = Braintree::PayPalAccount.update(
        original_token,
        :options => {:make_default => true}
      )

      updated_paypal_account = Braintree::PayPalAccount.find(original_token)
      updated_paypal_account.should be_default
    end

    it "returns an error if a token for account is used to attempt an update" do
      customer = Braintree::Customer.create!
      first_token = random_payment_method_token
      second_token = random_payment_method_token

      first_nonce = nonce_for_paypal_account(
        :consent_code => "consent-code",
        :token => first_token
      )
      first_result = Braintree::PaymentMethod.create(
        :payment_method_nonce => first_nonce,
        :customer_id => customer.id
      )

      second_nonce = nonce_for_paypal_account(
        :consent_code => "consent-code",
        :token => second_token
      )
      second_result = Braintree::PaymentMethod.create(
        :payment_method_nonce => second_nonce,
        :customer_id => customer.id
      )

      updated_result = Braintree::PayPalAccount.update(
        first_token,
        :token => second_token
      )

      updated_result.should_not be_success
      updated_result.errors.first.code.should == "92906"
    end
  end

  context "self.delete" do
    it "deletes a PayPal account" do
      customer = Braintree::Customer.create!
      token = random_payment_method_token

      nonce = nonce_for_paypal_account(
        :consent_code => "consent-code",
        :token => token
      )
      Braintree::PaymentMethod.create(
        :payment_method_nonce => nonce,
        :customer_id => customer.id
      )

      result = Braintree::PayPalAccount.delete(token)

      expect do
        Braintree::PayPalAccount.find(token)
      end.to raise_error(Braintree::NotFoundError, "payment method with token \"#{token}\" not found")
    end
  end

  context "self.sale" do
    it "creates a transaction using a paypal account and returns a result object" do
      customer = Braintree::Customer.create!(
        :payment_method_nonce => Braintree::Test::Nonce::PayPalFuturePayment
      )

      result = Braintree::PayPalAccount.sale(customer.paypal_accounts[0].token, :amount => "100.00")

      result.success?.should == true
      result.transaction.amount.should == BigDecimal("100.00")
      result.transaction.type.should == "sale"
      result.transaction.customer_details.id.should == customer.id
      result.transaction.paypal_details.token.should == customer.paypal_accounts[0].token
    end
  end

  context "self.sale!" do
    it "creates a transaction using a paypal account and returns a transaction" do
      customer = Braintree::Customer.create!(
        :payment_method_nonce => Braintree::Test::Nonce::PayPalFuturePayment
      )

      transaction = Braintree::PayPalAccount.sale!(customer.paypal_accounts[0].token, :amount => "100.00")

      transaction.amount.should == BigDecimal("100.00")
      transaction.type.should == "sale"
      transaction.customer_details.id.should == customer.id
      transaction.paypal_details.token.should == customer.paypal_accounts[0].token
    end
  end
end
