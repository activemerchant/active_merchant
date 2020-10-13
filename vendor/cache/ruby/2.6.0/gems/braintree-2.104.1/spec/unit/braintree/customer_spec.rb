require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::Customer do
  describe "inspect" do
    it "includes the id first" do
      output = Braintree::Customer._new(:gateway, {:first_name => 'Dan', :id => '1234'}).inspect
      output.should include("#<Braintree::Customer id: \"1234\",")
    end

    it "includes all customer attributes" do
      customer = Braintree::Customer._new(
        :gateway,
        :company => "Company",
        :email => "e@mail.com",
        :fax => "483-438-5821",
        :first_name => "Patrick",
        :last_name => "Smith",
        :phone => "802-483-5932",
        :website => "patrick.smith.com",
        :created_at => Time.now,
        :updated_at => Time.now
      )
      output = customer.inspect
      output.should include(%q(company: "Company"))
      output.should include(%q(email: "e@mail.com"))
      output.should include(%q(fax: "483-438-5821"))
      output.should include(%q(first_name: "Patrick"))
      output.should include(%q(last_name: "Smith"))
      output.should include(%q(phone: "802-483-5932"))
      output.should include(%q(website: "patrick.smith.com"))
      output.should include(%q(addresses: []))
      output.should include(%q(credit_cards: []))
      output.should include(%q(paypal_accounts: []))
      output.should include(%Q(created_at: #{customer.created_at.inspect}))
      output.should include(%Q(updated_at: #{customer.updated_at.inspect}))
    end
  end

  describe "self.create" do
    it "raises an exception if hash includes an invalid key" do
      expect do
        Braintree::Customer.create(:first_name => "Joe", :invalid_key => "foo")
      end.to raise_error(ArgumentError, "invalid keys: invalid_key")
    end
  end

  describe "self.find" do
    it "raises an exception if the id is blank" do
      expect do
        Braintree::Customer.find("  ")
      end.to raise_error(ArgumentError)
    end

    it "raises an exception if the id is nil" do
      expect do
        Braintree::Customer.find(nil)
      end.to raise_error(ArgumentError)
    end

    it "does not raise an exception if the id is a fixnum" do
      Braintree::Http.stub(:new).and_return double.as_null_object
      expect do
        Braintree::Customer.find(8675309)
      end.to_not raise_error
    end
  end

  describe "self.update" do
    it "raises an exception if hash includes an invalid key" do
      expect do
        Braintree::Customer.update("customer_id", :first_name => "Joe", :invalid_key => "foo")
      end.to raise_error(ArgumentError, "invalid keys: invalid_key")
    end
  end

  describe "self.create_signature" do
    it "should be what we expect" do
      Braintree::CustomerGateway._create_signature.should == [
        :company,
        :email,
        :fax,
        :first_name,
        :id,
        :last_name,
        :phone,
        :website,
        :device_data,
        :payment_method_nonce,
        {:risk_data => [:customer_browser, :customer_ip]},
        {:credit_card => [
          :billing_address_id,
          :cardholder_name,
          :cvv,
          :device_session_id,
          :expiration_date,
          :expiration_month,
          :expiration_year,
          :number,
          :token,
          :venmo_sdk_payment_method_code,
          :device_data,
          :fraud_merchant_id,
          :payment_method_nonce,
          {:external_vault=>[:network_transaction_id]},
          {:options => [:make_default, :verification_merchant_account_id, :verify_card, :verification_amount, :venmo_sdk_session, :fail_on_duplicate_payment_method, :verification_account_type]},
          {:billing_address => [
            :company,
            :country_code_alpha2,
            :country_code_alpha3,
            :country_code_numeric,
            :country_name,
            :extended_address,
            :first_name,
            :last_name,
            :locality,
            :phone_number,
            :postal_code,
            :region,
            :street_address
          ]},
          {:three_d_secure_pass_thru => [
            :eci_flag,
            :cavv,
            :xid,
            :three_d_secure_version,
            :authentication_response,
            :directory_response,
            :cavv_algorithm,
            :ds_transaction_id,
          ]},
        ]},
        {:paypal_account => [
          :email,
          :token,
          :billing_agreement_id,
          {:options => [:make_default]},
        ]},
        {:options =>
          [:paypal => [
            :payee_email,
            :order_id,
            :custom_field,
            :description,
            :amount,
            {:shipping => [
              :company,
              :country_code_alpha2,
              :country_code_alpha3,
              :country_code_numeric,
              :country_name,
              :extended_address,
              :first_name,
              :last_name,
              :locality,
              :phone_number,
              :postal_code,
              :region,
              :street_address,
            ]}
          ]]
        },
        {:custom_fields => :_any_key_}
      ]
    end
  end

  describe "self.update_signature" do
    it "should be what we expect" do
      Braintree::CustomerGateway._update_signature.should == [
        :company,
        :email,
        :fax,
        :first_name,
        :id,
        :last_name,
        :phone,
        :website,
        :device_data,
        :payment_method_nonce,
        :default_payment_method_token,
        {:credit_card => [
          :billing_address_id,
          :cardholder_name,
          :cvv,
          :device_session_id,
          :expiration_date,
          :expiration_month,
          :expiration_year,
          :number,
          :token,
          :venmo_sdk_payment_method_code,
          :device_data,
          :fraud_merchant_id,
          :payment_method_nonce,
          {:external_vault=>[:network_transaction_id]},
          {:options => [
            :make_default,
            :verification_merchant_account_id,
            :verify_card,
            :verification_amount,
            :venmo_sdk_session,
            :fail_on_duplicate_payment_method,
            :verification_account_type,
            :update_existing_token
          ]},
          {:billing_address => [
            :company,
            :country_code_alpha2,
            :country_code_alpha3,
            :country_code_numeric,
            :country_name,
            :extended_address,
            :first_name,
            :last_name,
            :locality,
            :phone_number,
            :postal_code,
            :region,
            :street_address,
            {:options => [:update_existing]}
          ]},
          {:three_d_secure_pass_thru => [
            :eci_flag,
            :cavv,
            :xid,
            :three_d_secure_version,
            :authentication_response,
            :directory_response,
            :cavv_algorithm,
            :ds_transaction_id,
          ]},
        ]},
        {:options =>
          [:paypal => [
            :payee_email,
            :order_id,
            :custom_field,
            :description,
            :amount,
            {:shipping => [
              :company,
              :country_code_alpha2,
              :country_code_alpha3,
              :country_code_numeric,
              :country_name,
              :extended_address,
              :first_name,
              :last_name,
              :locality,
              :phone_number,
              :postal_code,
              :region,
              :street_address,
            ]}
          ]]
        },
        {:custom_fields => :_any_key_}
      ]
    end
  end

  describe "self.create_from_transparent_redirect" do
    it "raises an exception if the query string is forged" do
      expect do
        Braintree::Customer.create_from_transparent_redirect("http_status=200&forged=query_string")
      end.to raise_error(Braintree::ForgedQueryString)
    end
  end

  describe "==" do
    it "returns true when given a customer with the same id" do
      first = Braintree::Customer._new(:gateway, :id => 123)
      second = Braintree::Customer._new(:gateway, :id => 123)

      first.should == second
      second.should == first
    end

    it "returns false when given a customer with a different id" do
      first = Braintree::Customer._new(:gateway, :id => 123)
      second = Braintree::Customer._new(:gateway, :id => 124)

      first.should_not == second
      second.should_not == first
    end

    it "returns false when not given a customer" do
      customer = Braintree::Customer._new(:gateway, :id => 123)
      customer.should_not == "not a customer"
    end
  end

  describe "initialize" do
    it "converts payment method hashes into payment method objects" do
      customer = Braintree::Customer._new(
        :gateway,
        :credit_cards => [
          {:token => "credit_card_1"},
          {:token => "credit_card_2"}
        ],
        :paypal_accounts => [
          {:token => "paypal_1"},
          {:token => "paypal_2"}
        ]
      )

      customer.credit_cards.size.should == 2
      customer.credit_cards[0].token.should == "credit_card_1"
      customer.credit_cards[1].token.should == "credit_card_2"

      customer.paypal_accounts.size.should == 2
      customer.paypal_accounts[0].token.should == "paypal_1"
      customer.paypal_accounts[1].token.should == "paypal_2"

      customer.payment_methods.count.should == 4
      customer.payment_methods.map(&:token).should include("credit_card_1")
      customer.payment_methods.map(&:token).should include("credit_card_2")
      customer.payment_methods.map(&:token).should include("paypal_1")
      customer.payment_methods.map(&:token).should include("paypal_2")
    end
  end

  describe "new" do
    it "is protected" do
      expect do
        Braintree::Customer.new
      end.to raise_error(NoMethodError, /protected method .new/)
    end
  end
end
