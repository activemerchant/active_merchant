require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::TransparentRedirect do
  it "raises a DownForMaintenanceError when app is in maintenance mode on TR requests" do
    tr_data = Braintree::TransparentRedirect.create_customer_data({:redirect_url => "http://example.com"}.merge({}))
    query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, {}, Braintree::Configuration.instantiate.base_merchant_url + "/test/maintenance")
    expect do
      Braintree::Customer.create_from_transparent_redirect(query_string_response)
    end.to raise_error(Braintree::DownForMaintenanceError)
  end

  it "raises a DownForMaintenanceError when the request times out", :if => ENV['UNICORN'] do
    tr_data = Braintree::TransparentRedirect.create_customer_data({:redirect_url => "http://example.com"}.merge({}))
    query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, {}, Braintree::Configuration.instantiate.base_merchant_url + "/test/die")
    expect do
      Braintree::Customer.create_from_transparent_redirect(query_string_response)
    end.to raise_error(Braintree::DownForMaintenanceError)
  end

  it "raises an AuthenticationError when authentication fails on TR requests" do
    SpecHelper.using_configuration(:private_key => "incorrect") do
      tr_data = Braintree::TransparentRedirect.create_customer_data({:redirect_url => "http://example.com"}.merge({}))
      query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, {}, Braintree::Customer.create_customer_url)
      expect do
        Braintree::Customer.create_from_transparent_redirect(query_string_response)
      end.to raise_error(Braintree::AuthenticationError)
    end
  end

  describe "self.confirm" do
    context "transaction" do
      it "successfully confirms a transaction create" do
        params = {
          :transaction => {
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "05/2009"
            }
          }
        }
        tr_data_params = {
          :transaction => {
            :type => "sale"
          }
        }
        tr_data = Braintree::TransparentRedirect.transaction_data({:redirect_url => "http://example.com"}.merge(tr_data_params))
        query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params)
        result = Braintree::TransparentRedirect.confirm(query_string_response)

        result.success?.should == true
        transaction = result.transaction
        transaction.type.should == "sale"
        transaction.amount.should == BigDecimal("1000.00")
        transaction.credit_card_details.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
        transaction.credit_card_details.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
        transaction.credit_card_details.expiration_date.should == "05/2009"
      end

      it "allows specifying a service fee" do
        params = {
          :transaction => {
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :merchant_account_id => SpecHelper::NonDefaultSubMerchantAccountId,
            :credit_card => {
              :number => Braintree::Test::CreditCardNumbers::Visa,
              :expiration_date => "05/2009"
            },
            :service_fee_amount => "1.00"
          }
        }
        tr_data_params = {
          :transaction => {
            :type => "sale"
          }
        }
        tr_data = Braintree::TransparentRedirect.transaction_data({:redirect_url => "http://example.com"}.merge(tr_data_params))
        query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params)
        result = Braintree::TransparentRedirect.confirm(query_string_response)
        result.success?.should == true
        result.transaction.service_fee_amount.should == BigDecimal("1.00")
      end

      it "returns an error when there's an error" do
        params = {
          :transaction => {
            :amount => Braintree::Test::TransactionAmounts::Authorize,
            :credit_card => {
              :number => "abc",
              :expiration_date => "05/2009"
            }
          }
        }
        tr_data_params = {
          :transaction => {
            :type => "sale"
          }
        }
        tr_data = Braintree::TransparentRedirect.transaction_data({:redirect_url => "http://example.com"}.merge(tr_data_params))
        query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params)
        result = Braintree::TransparentRedirect.confirm(query_string_response)

        result.success?.should == false
        result.errors.for(:transaction).for(:credit_card).on(:number).size.should > 0
      end
    end

    context "customer" do
      it "successfully confirms a customer create" do
        params = {
          :customer => {
            :first_name => "John",
          }
        }
        tr_data_params = {
          :customer => {
            :last_name => "Doe",
          }
        }
        tr_data = Braintree::TransparentRedirect.create_customer_data({:redirect_url => "http://example.com"}.merge(tr_data_params))
        query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params)
        result = Braintree::TransparentRedirect.confirm(query_string_response)

        result.success?.should == true
        customer = result.customer
        customer.first_name.should == "John"
        customer.last_name.should == "Doe"
      end

      it "successfully confirms a customer update" do
        customer = Braintree::Customer.create(
          :first_name => "Joe",
          :last_name => "Cool"
        ).customer

        params = {
          :customer => {
            :first_name => "John",
          }
        }
        tr_data_params = {
          :customer_id => customer.id,
          :customer => {
            :last_name => "Uncool",
          }
        }
        tr_data = Braintree::TransparentRedirect.update_customer_data({:redirect_url => "http://example.com"}.merge(tr_data_params))
        query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params)
        result = Braintree::TransparentRedirect.confirm(query_string_response)

        result.success?.should == true
        customer = Braintree::Customer.find(customer.id)
        customer.first_name.should == "John"
        customer.last_name.should == "Uncool"
      end

      it "returns an error result when there are errors" do
        params = {
          :customer => {
            :first_name => "John",
          }
        }
        tr_data_params = {
          :customer => {
            :last_name => "Doe",
            :email => "invalid"
          }
        }
        tr_data = Braintree::TransparentRedirect.create_customer_data({:redirect_url => "http://example.com"}.merge(tr_data_params))
        query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params)
        result = Braintree::TransparentRedirect.confirm(query_string_response)

        result.success?.should == false
        result.errors.for(:customer).on(:email).size.should > 0
      end
    end

    context "credit_card" do
      it "successfully confirms a credit_card create" do
        customer = Braintree::Customer.create(:first_name => "John", :last_name => "Doe").customer

        params = {
          :credit_card => {
            :cardholder_name => "John Doe"
          }
        }
        tr_data_params = {
          :credit_card => {
            :customer_id => customer.id,
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "10/10"
          }
        }
        tr_data = Braintree::TransparentRedirect.create_credit_card_data(
          {:redirect_url => "http://example.com"}.merge(tr_data_params)
        )
        query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params)
        result = Braintree::TransparentRedirect.confirm(query_string_response)

        result.success?.should == true
        credit_card = result.credit_card
        credit_card.cardholder_name.should == "John Doe"
        credit_card.bin.should == Braintree::Test::CreditCardNumbers::Visa[0, 6]
        credit_card.last_4.should == Braintree::Test::CreditCardNumbers::Visa[-4..-1]
        credit_card.expiration_date.should == "10/2010"
      end

      it "successfully confirms a credit_card update" do
        customer = Braintree::Customer.create(:first_name => "John", :last_name => "Doe").customer
        credit_card = Braintree::CreditCard.create(
          :customer_id => customer.id,
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "10/10"
        ).credit_card

        params = {
          :credit_card => {
            :cardholder_name => "John Doe"
          }
        }
        tr_data_params = {
          :payment_method_token => credit_card.token,
          :credit_card => {
            :number => Braintree::Test::CreditCardNumbers::MasterCard,
            :expiration_date => "11/11"
          }
        }
        tr_data = Braintree::TransparentRedirect.update_credit_card_data(
          {:redirect_url => "http://example.com"}.merge(tr_data_params)
        )
        query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params)
        result = Braintree::TransparentRedirect.confirm(query_string_response)

        result.success?.should == true
        credit_card = result.credit_card
        credit_card.cardholder_name.should == "John Doe"
        credit_card.bin.should == Braintree::Test::CreditCardNumbers::MasterCard[0, 6]
        credit_card.last_4.should == Braintree::Test::CreditCardNumbers::MasterCard[-4..-1]
        credit_card.expiration_date.should == "11/2011"
      end

      it "returns an error result where there are errors" do
        customer = Braintree::Customer.create(:first_name => "John", :last_name => "Doe").customer

        params = {
          :credit_card => {
            :cardholder_name => "John Doe"
          }
        }
        tr_data_params = {
          :credit_card => {
            :customer_id => customer.id,
            :number => Braintree::Test::CreditCardNumbers::Visa,
            :expiration_date => "123"
          }
        }
        tr_data = Braintree::TransparentRedirect.create_credit_card_data(
          {:redirect_url => "http://example.com"}.merge(tr_data_params)
        )
        query_string_response = SpecHelper.simulate_form_post_for_tr(tr_data, params)
        result = Braintree::TransparentRedirect.confirm(query_string_response)

        result.success?.should == false
        result.errors.for(:credit_card).size.should > 0
      end
    end
  end
end
