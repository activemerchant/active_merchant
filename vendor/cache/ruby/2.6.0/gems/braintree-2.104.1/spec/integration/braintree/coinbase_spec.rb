require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe "Coinbase" do

  def assert_valid_coinbase_attrs(account_or_details)
    [:user_id, :user_name, :user_email].each do |attr|
      [nil,""].should_not include(account_or_details.send(attr))
    end
  end

  it "is no longer supported with transaction#create" do
    result = Braintree::Transaction.sale(:payment_method_nonce => Braintree::Test::Nonce::Coinbase, :amount => "0.02")
    result.should_not be_success

    result.errors.for(:transaction).first.code.should == Braintree::ErrorCodes::PaymentMethod::PaymentMethodNoLongerSupported
  end

  it "is no longer supported for vaulting" do
    customer = Braintree::Customer.create!
    result = Braintree::PaymentMethod.create(:customer_id => customer.id, :payment_method_nonce => Braintree::Test::Nonce::Coinbase)
    result.should_not be_success

    result.errors.for(:coinbase_account).first.code.should == Braintree::ErrorCodes::PaymentMethod::PaymentMethodNoLongerSupported
  end

  it "is no longer supported when creating a Customer with a Coinbase payment method nonce" do
    expect do
      Braintree::Customer.create!(:payment_method_nonce => Braintree::Test::Nonce::Coinbase)
    end.to raise_error { |error|
      error.should be_a(Braintree::ValidationsFailed)
      error.error_result.errors.for(:coinbase_account).first.code.should == Braintree::ErrorCodes::PaymentMethod::PaymentMethodNoLongerSupported
    }
  end
end
