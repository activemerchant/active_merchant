require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require File.expand_path(File.dirname(__FILE__) + "/client_api/spec_helper")

describe Braintree::SamsungPayCard do
  it "can create from payment method nonce" do
    customer = Braintree::Customer.create!

    result = Braintree::PaymentMethod.create(
      :payment_method_nonce => Braintree::Test::Nonce::SamsungPayDiscover,
      :customer_id => customer.id,
      :cardholder_name => 'Jenny Block',
      :billing_address => {
          :first_name => "New First Name",
          :last_name => "New Last Name",
          :company => "New Company",
          :street_address => "123 New St",
          :extended_address => "Apt New",
          :locality => "New City",
          :region => "New State",
          :postal_code => "56789",
          :country_name => "United States of America"
      }
    )
    result.should be_success

    samsung_pay_card = result.payment_method
    samsung_pay_card.should be_a(Braintree::SamsungPayCard)
    samsung_pay_card.billing_address.should_not be_nil
    samsung_pay_card.bin.should_not be_nil
    samsung_pay_card.cardholder_name.should_not be_nil
    samsung_pay_card.card_type.should_not be_nil
    samsung_pay_card.commercial.should_not be_nil
    samsung_pay_card.country_of_issuance.should_not be_nil
    samsung_pay_card.created_at.should_not be_nil
    samsung_pay_card.customer_id.should_not be_nil
    samsung_pay_card.customer_location.should_not be_nil
    samsung_pay_card.debit.should_not be_nil
    samsung_pay_card.default?.should_not be_nil
    samsung_pay_card.durbin_regulated.should_not be_nil
    samsung_pay_card.expiration_date.should_not be_nil
    samsung_pay_card.expiration_month.should_not be_nil
    samsung_pay_card.expiration_year.should_not be_nil
    samsung_pay_card.expired?.should_not be_nil
    samsung_pay_card.healthcare.should_not be_nil
    samsung_pay_card.image_url.should_not be_nil
    samsung_pay_card.issuing_bank.should_not be_nil
    samsung_pay_card.last_4.should_not be_nil
    samsung_pay_card.payroll.should_not be_nil
    samsung_pay_card.prepaid.should_not be_nil
    samsung_pay_card.product_id.should_not be_nil
    samsung_pay_card.source_card_last_4.should_not be_nil
    samsung_pay_card.subscriptions.should_not be_nil
    samsung_pay_card.token.should_not be_nil
    samsung_pay_card.unique_number_identifier.should_not be_nil
    samsung_pay_card.updated_at.should_not be_nil

    customer = Braintree::Customer.find(customer.id)
    customer.samsung_pay_cards.size.should == 1
    customer.samsung_pay_cards.first.should == samsung_pay_card
  end

  it "returns cardholder_name and billing_address" do
    customer = Braintree::Customer.create!

    result = Braintree::PaymentMethod.create(
      :payment_method_nonce => Braintree::Test::Nonce::SamsungPayDiscover,
      :customer_id => customer.id,
      :cardholder_name => 'Jenny Block',
      :billing_address => {
          :first_name => "New First Name",
          :last_name => "New Last Name",
          :company => "New Company",
          :street_address => "123 New St",
          :extended_address => "Apt New",
          :locality => "New City",
          :region => "New State",
          :postal_code => "56789",
          :country_name => "United States of America"
      }
    )

    result.should be_success
    result.payment_method.cardholder_name.should == 'Jenny Block'

    address = result.payment_method.billing_address
    address.first_name.should == "New First Name"
    address.last_name.should == "New Last Name"
    address.company.should == "New Company"
    address.street_address.should == "123 New St"
    address.extended_address.should == "Apt New"
    address.locality.should == "New City"
    address.region.should == "New State"
    address.postal_code.should == "56789"
  end

  it "can search for transactions" do
    transaction_create_result = Braintree::Transaction.sale(
      :payment_method_nonce => Braintree::Test::Nonce::SamsungPayDiscover,
      :amount => '47.00',
    )
    transaction_create_result.should be_success
    transaction_id = transaction_create_result.transaction.id

    search_results = Braintree::Transaction.search do |search|
      search.id.is transaction_id
      search.payment_instrument_type.is Braintree::PaymentInstrumentType::SamsungPayCard
    end
    search_results.first.id.should == transaction_id
  end

  it "can create transaction from nonce and vault" do
    customer = Braintree::Customer.create!

    result = Braintree::Transaction.sale(
      :payment_method_nonce => Braintree::Test::Nonce::SamsungPayDiscover,
      :customer_id => customer.id,
      :amount => '47.00',
      :options => { :store_in_vault => true },
    )
    result.should be_success

    samsung_pay_card_details = result.transaction.samsung_pay_card_details
    samsung_pay_card_details.bin.should_not be_nil
    samsung_pay_card_details.card_type.should_not be_nil
    samsung_pay_card_details.commercial.should_not be_nil
    samsung_pay_card_details.country_of_issuance.should_not be_nil
    samsung_pay_card_details.customer_location.should_not be_nil
    samsung_pay_card_details.debit.should_not be_nil
    samsung_pay_card_details.durbin_regulated.should_not be_nil
    samsung_pay_card_details.expiration_date.should_not be_nil
    samsung_pay_card_details.expiration_month.should_not be_nil
    samsung_pay_card_details.expiration_year.should_not be_nil
    samsung_pay_card_details.healthcare.should_not be_nil
    samsung_pay_card_details.image_url.should_not be_nil
    samsung_pay_card_details.issuing_bank.should_not be_nil
    samsung_pay_card_details.last_4.should_not be_nil
    samsung_pay_card_details.payroll.should_not be_nil
    samsung_pay_card_details.prepaid.should_not be_nil
    samsung_pay_card_details.product_id.should_not be_nil
    samsung_pay_card_details.source_card_last_4.should_not be_nil
    samsung_pay_card_details.source_card_last_4.should == '3333'
    samsung_pay_card_details.token.should_not be_nil
  end
end
