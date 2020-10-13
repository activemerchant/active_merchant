require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require File.expand_path(File.dirname(__FILE__) + "/client_api/spec_helper")

describe Braintree::UsBankAccountVerification, "search" do
  it "correctly returns a result with no matches" do
    collection = Braintree::UsBankAccountVerification.search do |search|
      search.account_holder_name.is "thisnameisnotreal"
    end

    collection.maximum_size.should == 0
  end

  let(:nonce) { generate_non_plaid_us_bank_account_nonce }

  it "can search on text fields" do
    customer = Braintree::Customer.create(
      :email => "john.doe@example.com",
    ).customer
    payment_method = Braintree::PaymentMethod.create(
      :payment_method_nonce => nonce,
      :customer_id => customer.id,
      :options => {
        :verification_merchant_account_id => SpecHelper::UsBankMerchantAccountId,
      }
    ).payment_method
    verification = payment_method.verifications.first

    search_criteria = {
      :id => verification.id,
      :account_holder_name => "John Doe",
      :routing_number => "021000021",
      :payment_method_token => payment_method.token,
      :account_type => "checking",
      :customer_id => customer.id,
      :customer_email => "john.doe@example.com",
    }

    search_criteria.each do |criterion, value|
      collection = Braintree::UsBankAccountVerification.search do |search|
        search.id.is verification.id
        search.send(criterion).is value
      end
      collection.maximum_size.should == 1
      collection.first.id.should == verification.id

      collection = Braintree::UsBankAccountVerification.search do |search|
        search.id.is verification.id
        search.send(criterion).is "invalid_attribute"
      end
      collection.should be_empty
    end

    collection = Braintree::UsBankAccountVerification.search do |search|
      search.id.is verification.id
      search_criteria.each do |criterion, value|
        search.send(criterion).is value
      end
    end

    collection.maximum_size.should == 1
    collection.first.id.should == verification.id
  end

  describe "multiple value fields" do
    it "searches on ids" do
      customer = Braintree::Customer.create.customer

      payment_method1 = Braintree::PaymentMethod.create(
        :payment_method_nonce => generate_non_plaid_us_bank_account_nonce,
        :customer_id => customer.id,
        :options => {
          :verification_merchant_account_id => SpecHelper::UsBankMerchantAccountId,
        }
      ).payment_method
      verification1 = payment_method1.verifications.first

      payment_method2 = Braintree::PaymentMethod.create(
        :payment_method_nonce => generate_non_plaid_us_bank_account_nonce,
        :customer_id => customer.id,
        :options => {
          :verification_merchant_account_id => SpecHelper::UsBankMerchantAccountId,
        }
      ).payment_method
      verification2 = payment_method2.verifications.first

      collection = Braintree::UsBankAccountVerification.search do |search|
        search.ids.in verification1.id, verification2.id
      end

      collection.maximum_size.should == 2
    end
  end

  context "range fields" do
    it "searches on created_at" do
      customer = Braintree::Customer.create.customer

      payment_method = Braintree::PaymentMethod.create(
        :payment_method_nonce => generate_non_plaid_us_bank_account_nonce,
        :customer_id => customer.id,
        :options => {
          :verification_merchant_account_id => SpecHelper::UsBankMerchantAccountId,
        }
      ).payment_method
      verification = payment_method.verifications.first

      created_at = verification.created_at

      collection = Braintree::UsBankAccountVerification.search do |search|
        search.id.is verification.id
        search.created_at.between(
          created_at - 60,
          created_at + 60
        )
      end

      collection.maximum_size.should == 1
      collection.first.id.should == verification.id

      collection = Braintree::UsBankAccountVerification.search do |search|
        search.id.is verification.id
        search.created_at >= created_at - 1
      end

      collection.maximum_size.should == 1
      collection.first.id.should == verification.id

      collection = Braintree::UsBankAccountVerification.search do |search|
        search.id.is verification.id
        search.created_at <= created_at + 1
      end

      collection.maximum_size.should == 1
      collection.first.id.should == verification.id

      collection = Braintree::UsBankAccountVerification.search do |search|
        search.id.is verification.id
        search.created_at.between(
          created_at - 300,
          created_at - 100
        )
      end

      collection.maximum_size.should == 0

      collection = Braintree::UsBankAccountVerification.search do |search|
        search.id.is verification.id
        search.created_at.is created_at
      end

      collection.maximum_size.should == 1
      collection.first.id.should == verification.id
    end
  end

  context "ends with fields" do
    it "does ends_with search on account_number" do
      customer = Braintree::Customer.create.customer

      payment_method = Braintree::PaymentMethod.create(
        :payment_method_nonce => nonce,
        :customer_id => customer.id,
        :options => {
          :verification_merchant_account_id => SpecHelper::UsBankMerchantAccountId,
        }
      ).payment_method
      verification = payment_method.verifications.first

      collection = Braintree::UsBankAccountVerification.search do |search|
        search.id.is verification.id
        search.account_number.ends_with "0000"
      end

      collection.maximum_size.should == 1
      collection.first.id.should == verification.id
    end
  end
end
