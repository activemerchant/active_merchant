require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require File.expand_path(File.dirname(__FILE__) + "/client_api/spec_helper")

describe Braintree::MasterpassCard do
  it "can create from a payment method nonce" do
    customer = Braintree::Customer.create!

    result = Braintree::PaymentMethod.create(
      :payment_method_nonce => Braintree::Test::Nonce::MasterpassDiscover,
      :customer_id => customer.id
    )
    result.should be_success

    masterpass_card = result.payment_method
    masterpass_card.should be_a(Braintree::MasterpassCard)
    masterpass_card.billing_address.should_not be_nil
    masterpass_card.bin.should_not be_nil
    masterpass_card.card_type.should_not be_nil
    masterpass_card.cardholder_name.should_not be_nil
    masterpass_card.commercial.should_not be_nil
    masterpass_card.country_of_issuance.should_not be_nil
    masterpass_card.created_at.should_not be_nil
    masterpass_card.customer_id.should_not be_nil
    masterpass_card.customer_location.should_not be_nil
    masterpass_card.debit.should_not be_nil
    masterpass_card.default?.should_not be_nil
    masterpass_card.durbin_regulated.should_not be_nil
    masterpass_card.expiration_date.should_not be_nil
    masterpass_card.expiration_month.should_not be_nil
    masterpass_card.expiration_year.should_not be_nil
    masterpass_card.expired?.should_not be_nil
    masterpass_card.healthcare.should_not be_nil
    masterpass_card.image_url.should_not be_nil
    masterpass_card.issuing_bank.should_not be_nil
    masterpass_card.last_4.should_not be_nil
    masterpass_card.payroll.should_not be_nil
    masterpass_card.prepaid.should_not be_nil
    masterpass_card.product_id.should_not be_nil
    masterpass_card.subscriptions.should_not be_nil
    masterpass_card.token.should_not be_nil
    masterpass_card.unique_number_identifier.should_not be_nil
    masterpass_card.updated_at.should_not be_nil

    customer = Braintree::Customer.find(customer.id)
    customer.masterpass_cards.size.should == 1
    customer.masterpass_cards.first.should == masterpass_card
  end

  it "can search for transactions" do
    transaction_create_result = Braintree::Transaction.sale(
      :payment_method_nonce => Braintree::Test::Nonce::MasterpassDiscover,
      :amount => '47.00',
    )
    transaction_create_result.should be_success
    transaction_id = transaction_create_result.transaction.id

    search_results = Braintree::Transaction.search do |search|
      search.id.is transaction_id
      search.payment_instrument_type.is Braintree::PaymentInstrumentType::MasterpassCard
    end
    search_results.first.id.should == transaction_id
  end

  it "can create transaction from nonce and vault" do
    customer = Braintree::Customer.create!

    result = Braintree::Transaction.sale(
      :payment_method_nonce => Braintree::Test::Nonce::MasterpassDiscover,
      :customer_id => customer.id,
      :amount => '47.00',
      :options => { :store_in_vault => true },
    )
    result.should be_success

    masterpass_card_details = result.transaction.masterpass_card_details
    masterpass_card_details.bin.should_not be_nil
    masterpass_card_details.card_type.should_not be_nil
    masterpass_card_details.cardholder_name.should_not be_nil
    masterpass_card_details.commercial.should_not be_nil
    masterpass_card_details.country_of_issuance.should_not be_nil
    masterpass_card_details.customer_location.should_not be_nil
    masterpass_card_details.debit.should_not be_nil
    masterpass_card_details.durbin_regulated.should_not be_nil
    masterpass_card_details.expiration_date.should_not be_nil
    masterpass_card_details.expiration_month.should_not be_nil
    masterpass_card_details.expiration_year.should_not be_nil
    masterpass_card_details.healthcare.should_not be_nil
    masterpass_card_details.image_url.should_not be_nil
    masterpass_card_details.issuing_bank.should_not be_nil
    masterpass_card_details.last_4.should_not be_nil
    masterpass_card_details.payroll.should_not be_nil
    masterpass_card_details.prepaid.should_not be_nil
    masterpass_card_details.product_id.should_not be_nil
    masterpass_card_details.token.should_not be_nil
  end
end

