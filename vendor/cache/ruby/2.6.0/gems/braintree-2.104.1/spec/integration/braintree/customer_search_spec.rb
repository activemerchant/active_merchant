require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require File.expand_path(File.dirname(__FILE__) + "/client_api/spec_helper")

describe Braintree::Transaction, "search" do
  context "advanced" do
    it "correctly returns a result with no matches" do
      collection = Braintree::Customer.search do |search|
        search.first_name.is "thisnameisnotreal"
      end

      collection.maximum_size.should == 0
    end

    it "can search on text fields" do
      cctoken = "cctoken_#{rand(10**10)}"
      customer = Braintree::Customer.create!(
        :first_name => "Timmy",
        :last_name => "O'Toole",
        :company => "O'Toole and #{rand(1_000_000)} Son(s)",
        :email => "timmy@example.com",
        :fax => "3145551234",
        :phone => "5551231234",
        :website => "http://example.com",
        :credit_card => {
          :cardholder_name => "Tim Tool",
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2010",
          :token => cctoken,
          :billing_address => {
            :first_name => "Thomas",
            :last_name => "Otool",
            :street_address => "1 E Main St",
            :extended_address => "Suite 3",
            :locality => "Chicago",
            :region => "Illinois",
            :postal_code => "60622",
            :country_name => "United States of America"
          }
        }
      )

      customer = Braintree::Customer.find(customer.id)

      search_criteria = {
        :first_name                  => "Timmy",
        :last_name                   => "O'Toole",
        :company                     => customer.company,
        :email                       => "timmy@example.com",
        :phone                       => "5551231234",
        :fax                         => "3145551234",
        :website                     => "http://example.com",
        :address_first_name          => "Thomas",
        :address_last_name           => "Otool",
        :address_street_address      => "1 E Main St",
        :address_postal_code         => "60622",
        :address_extended_address    => "Suite 3",
        :address_locality            => "Chicago",
        :address_region              => "Illinois",
        :address_country_name        => "United States of America",
        :payment_method_token        => cctoken,
        :cardholder_name             => "Tim Tool",
        :credit_card_expiration_date => "05/2010",
        :credit_card_number          => Braintree::Test::CreditCardNumbers::Visa
      }

      search_criteria.each do |criterion, value|
        collection = Braintree::Customer.search do |search|
          search.id.is customer.id
          search.send(criterion).is value
        end

        collection.maximum_size.should == 1
        collection.first.id.should == customer.id

        collection = Braintree::Customer.search do |search|
          search.id.is customer.id
          search.send(criterion).is("invalid_attribute")
        end
        collection.should be_empty
      end

      collection = Braintree::Customer.search do |search|
        search.id.is customer.id
        search_criteria.each do |criterion, value|
          search.send(criterion).is value
        end
      end

      collection.maximum_size.should == 1
      collection.first.id.should == customer.id
    end

    it "can find duplicate credit cards for a give payment method token " do
      jim = Braintree::Customer.create(
        :first_name => "Jim",
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Maestro,
          :expiration_date => "05/2012"
        }
      ).customer

      joe = Braintree::Customer.create(
        :first_name => "Joe",
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Maestro,
          :expiration_date => "05/2012"
        }
      ).customer

      collection = Braintree::Customer.search do |search|
        search.payment_method_token_with_duplicates.is jim.credit_cards.first.token
      end

      collection.should include(jim)
      collection.should include(joe)
    end

    it "can search by created_at" do
      company = "Company #{rand(1_000_000)}"
      customer = Braintree::Customer.create!(
        :company => company
      )

      created_at = customer.created_at
      created_at.should be_utc

      collection = Braintree::Customer.search do |search|
        search.company.is company
        search.created_at.between(
          created_at - 60,
          created_at + 60
        )
      end

      collection.maximum_size.should == 1
      collection.first.id.should == customer.id

      collection = Braintree::Customer.search do |search|
        search.company.is customer.company
        search.created_at >= created_at - 1
      end

      collection.maximum_size.should == 1
      collection.first.company.should == customer.company

      collection = Braintree::Customer.search do |search|
        search.company.is customer.company
        search.created_at <= created_at + 1
      end

      collection.maximum_size.should == 1
      collection.first.company.should == customer.company

      collection = Braintree::Customer.search do |search|
        search.company.is customer.company
        search.created_at.between(
          created_at - 300,
          created_at - 100
        )
      end

      collection.maximum_size.should == 0

      collection = Braintree::Customer.search do |search|
        search.company.is customer.company
        search.created_at.is created_at
      end

      collection.maximum_size.should == 1
      collection.first.company.should == customer.company
    end
  end

  it "can search by paypal_account_email" do
    paypal_token = rand(36**3).to_s(36)
    nonce = nonce_for_paypal_account(
      :consent_code => "PAYPAL_CONSENT_CODE",
      :token => paypal_token
    )

    customer_id = "UNIQUE_CUSTOMER_ID_" + rand(36**3).to_s(36)
    customer = Braintree::Customer.create!(
      :payment_method_nonce => nonce,
      :id => customer_id
    )

    collection = Braintree::Customer.search do |search|
      search.paypal_account_email.is "jane.doe@example.com"
      search.id.is customer_id
    end

    collection.maximum_size.should == 1
    collection.first.should == customer
  end
end
