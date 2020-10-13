require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require File.expand_path(File.dirname(__FILE__) + "/client_api/spec_helper")

describe Braintree::VisaCheckoutCard do
  it "can create from payment method nonce" do
    customer = Braintree::Customer.create!

    result = Braintree::PaymentMethod.create(
      :payment_method_nonce => Braintree::Test::Nonce::VisaCheckoutDiscover,
      :customer_id => customer.id
    )
    result.should be_success

    visa_checkout_card = result.payment_method
    visa_checkout_card.should be_a(Braintree::VisaCheckoutCard)
    visa_checkout_card.call_id.should == "abc123"
    visa_checkout_card.billing_address.should_not be_nil
    visa_checkout_card.bin.should_not be_nil
    visa_checkout_card.card_type.should_not be_nil
    visa_checkout_card.cardholder_name.should_not be_nil
    visa_checkout_card.commercial.should_not be_nil
    visa_checkout_card.country_of_issuance.should_not be_nil
    visa_checkout_card.created_at.should_not be_nil
    visa_checkout_card.customer_id.should_not be_nil
    visa_checkout_card.customer_location.should_not be_nil
    visa_checkout_card.debit.should_not be_nil
    visa_checkout_card.default?.should_not be_nil
    visa_checkout_card.durbin_regulated.should_not be_nil
    visa_checkout_card.expiration_date.should_not be_nil
    visa_checkout_card.expiration_month.should_not be_nil
    visa_checkout_card.expiration_year.should_not be_nil
    visa_checkout_card.expired?.should_not be_nil
    visa_checkout_card.healthcare.should_not be_nil
    visa_checkout_card.image_url.should_not be_nil
    visa_checkout_card.issuing_bank.should_not be_nil
    visa_checkout_card.last_4.should_not be_nil
    visa_checkout_card.payroll.should_not be_nil
    visa_checkout_card.prepaid.should_not be_nil
    visa_checkout_card.product_id.should_not be_nil
    visa_checkout_card.subscriptions.should_not be_nil
    visa_checkout_card.token.should_not be_nil
    visa_checkout_card.unique_number_identifier.should_not be_nil
    visa_checkout_card.updated_at.should_not be_nil

    customer = Braintree::Customer.find(customer.id)
    customer.visa_checkout_cards.size.should == 1
    customer.visa_checkout_cards.first.should == visa_checkout_card
  end

  it "can create with verification" do
    customer = Braintree::Customer.create!

    result = Braintree::PaymentMethod.create(
      :payment_method_nonce => Braintree::Test::Nonce::VisaCheckoutDiscover,
      :customer_id => customer.id,
      :options => { :verify_card => true }
    )
    result.should be_success
    result.payment_method.verification.status.should == Braintree::CreditCardVerification::Status::Verified
  end

  it "can search for transactions" do
    transaction_create_result = Braintree::Transaction.sale(
      :payment_method_nonce => Braintree::Test::Nonce::VisaCheckoutDiscover,
      :amount => '47.00',
    )
    transaction_create_result.should be_success
    transaction_id = transaction_create_result.transaction.id

    search_results = Braintree::Transaction.search do |search|
      search.id.is transaction_id
      search.payment_instrument_type.is Braintree::PaymentInstrumentType::VisaCheckoutCard
    end
    search_results.first.id.should == transaction_id
  end

  it "can create transaction from nonce and vault" do
    customer = Braintree::Customer.create!

    result = Braintree::Transaction.sale(
      :payment_method_nonce => Braintree::Test::Nonce::VisaCheckoutDiscover,
      :customer_id => customer.id,
      :amount => '47.00',
      :options => { :store_in_vault => true },
    )
    result.should be_success

    visa_checkout_card_details = result.transaction.visa_checkout_card_details
    visa_checkout_card_details.call_id.should == "abc123"
    visa_checkout_card_details.bin.should_not be_nil
    visa_checkout_card_details.card_type.should_not be_nil
    visa_checkout_card_details.cardholder_name.should_not be_nil
    visa_checkout_card_details.commercial.should_not be_nil
    visa_checkout_card_details.country_of_issuance.should_not be_nil
    visa_checkout_card_details.customer_location.should_not be_nil
    visa_checkout_card_details.debit.should_not be_nil
    visa_checkout_card_details.durbin_regulated.should_not be_nil
    visa_checkout_card_details.expiration_date.should_not be_nil
    visa_checkout_card_details.expiration_month.should_not be_nil
    visa_checkout_card_details.expiration_year.should_not be_nil
    visa_checkout_card_details.healthcare.should_not be_nil
    visa_checkout_card_details.image_url.should_not be_nil
    visa_checkout_card_details.issuing_bank.should_not be_nil
    visa_checkout_card_details.last_4.should_not be_nil
    visa_checkout_card_details.payroll.should_not be_nil
    visa_checkout_card_details.prepaid.should_not be_nil
    visa_checkout_card_details.product_id.should_not be_nil
    visa_checkout_card_details.token.should_not be_nil
  end
end
