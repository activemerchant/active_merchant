require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::Transaction do
  describe "self.clone_transaction" do
    it "raises an exception if hash includes an invalid key" do
      expect do
        Braintree::Transaction.clone_transaction("an_id", :amount => "10.00", :invalid_key => "foo")
      end.to raise_error(ArgumentError, "invalid keys: invalid_key")
    end
  end

  describe "self.create" do
    it "raises an exception if hash includes an invalid key" do
      expect do
        Braintree::Transaction.create(:amount => "Joe", :invalid_key => "foo")
      end.to raise_error(ArgumentError, "invalid keys: invalid_key")
    end
  end

  describe "self.create_from_transparent_redirect" do
    it "raises an exception if the query string is forged" do
      expect do
        Braintree::Transaction.create_from_transparent_redirect("http_status=200&forged=query_string")
      end.to raise_error(Braintree::ForgedQueryString)
    end
  end

  describe "self.find" do
    it "raises error if passed empty string" do
      expect do
        Braintree::Transaction.find("")
      end.to raise_error(ArgumentError)
    end

    it "raises error if passed empty string wth space" do
      expect do
        Braintree::Transaction.find(" ")
      end.to raise_error(ArgumentError)
    end

    it "raises error if passed nil" do
      expect do
        Braintree::Transaction.find(nil)
      end.to raise_error(ArgumentError)
    end
  end

  describe "self.create_transaction_url" do
    it "returns the url" do
      config = Braintree::Configuration.instantiate
      Braintree::Transaction.create_transaction_url.should == "http#{config.ssl? ? 's' : ''}://#{config.server}:#{config.port}/merchants/integration_merchant_id/transactions/all/create_via_transparent_redirect_request"
    end
  end

  describe "self.submit_for_settlement" do
    it "raises an ArgumentError if transaction_id is an invalid format" do
      expect do
        Braintree::Transaction.submit_for_settlement("invalid-transaction-id")
      end.to raise_error(ArgumentError, "transaction_id is invalid")
    end
  end

  describe "self.update_details" do
    it "raises an ArgumentError if transaction_id is an invalid format" do
      expect do
        Braintree::Transaction.update_details("invalid-transaction-id")
      end.to raise_error(ArgumentError, "transaction_id is invalid")
    end
  end

  describe "initialize" do
    it "sets up customer attributes in customer_details" do
      transaction = Braintree::Transaction._new(
        :gateway,
        :customer => {
          :id => "123",
          :first_name => "Adam",
          :last_name => "Taylor",
          :company => "Ledner LLC",
          :email => "adam.taylor@lednerllc.com",
          :website => "lednerllc.com",
          :phone => "1-999-652-4189 x56883",
          :fax => "012-161-8055"
        }
      )
      transaction.customer_details.id.should == "123"
      transaction.customer_details.first_name.should == "Adam"
      transaction.customer_details.last_name.should == "Taylor"
      transaction.customer_details.company.should == "Ledner LLC"
      transaction.customer_details.email.should == "adam.taylor@lednerllc.com"
      transaction.customer_details.website.should == "lednerllc.com"
      transaction.customer_details.phone.should == "1-999-652-4189 x56883"
      transaction.customer_details.fax.should == "012-161-8055"
    end

    it "sets up disbursement attributes in disbursement_details" do
      transaction = Braintree::Transaction._new(
        :gateway,
        :disbursement_details => {
          :disbursement_date => "2013-04-03",
          :settlement_amount => "120.00",
          :settlement_currency_iso_code => "USD",
          :settlement_currency_exchange_rate => "1",
          :funds_held => false,
          :success => true
        }
      )
      disbursement = transaction.disbursement_details
      disbursement.disbursement_date.should == "2013-04-03"
      disbursement.settlement_amount.should == "120.00"
      disbursement.settlement_currency_iso_code.should == "USD"
      disbursement.settlement_currency_exchange_rate.should == "1"
      disbursement.funds_held?.should be(false)
      disbursement.success?.should be(true)
    end

    it "sets up credit card attributes in credit_card_details" do
      transaction = Braintree::Transaction._new(
        :gateway,
        :credit_card => {
          :token => "mzg2",
          :bin => "411111",
          :last_4 => "1111",
          :card_type => "Visa",
          :expiration_month => "08",
          :expiration_year => "2009",
          :customer_location => "US",
          :prepaid => "Yes",
          :healthcare => "Yes",
          :durbin_regulated => "Yes",
          :debit => "Yes",
          :commercial => "No",
          :payroll => "Unknown",
          :product_id => "Unknown",
          :country_of_issuance => "Narnia",
          :issuing_bank => "Mr Tumnus"
        }
      )
      transaction.credit_card_details.token.should == "mzg2"
      transaction.credit_card_details.bin.should == "411111"
      transaction.credit_card_details.last_4.should == "1111"
      transaction.credit_card_details.card_type.should == "Visa"
      transaction.credit_card_details.expiration_month.should == "08"
      transaction.credit_card_details.expiration_year.should == "2009"
      transaction.credit_card_details.customer_location.should == "US"
      transaction.credit_card_details.prepaid.should == Braintree::CreditCard::Prepaid::Yes
      transaction.credit_card_details.healthcare.should == Braintree::CreditCard::Healthcare::Yes
      transaction.credit_card_details.durbin_regulated.should == Braintree::CreditCard::DurbinRegulated::Yes
      transaction.credit_card_details.debit.should == Braintree::CreditCard::Debit::Yes
      transaction.credit_card_details.commercial.should == Braintree::CreditCard::Commercial::No
      transaction.credit_card_details.payroll.should == Braintree::CreditCard::Payroll::Unknown
      transaction.credit_card_details.product_id.should == Braintree::CreditCard::ProductId::Unknown
      transaction.credit_card_details.country_of_issuance.should == "Narnia"
      transaction.credit_card_details.issuing_bank.should == "Mr Tumnus"
    end

    it "sets up three_d_secure_info" do
      transaction = Braintree::Transaction._new(
        :gateway,
        :three_d_secure_info => {
          :enrolled => "Y",
          :liability_shifted => true,
          :liability_shift_possible => true,
          :status => "authenticate_successful",
        }
      )

      transaction.three_d_secure_info.enrolled.should == "Y"
      transaction.three_d_secure_info.status.should == "authenticate_successful"
      transaction.three_d_secure_info.liability_shifted.should == true
      transaction.three_d_secure_info.liability_shift_possible.should == true
    end

    it "sets up ideal_payment_details" do
      transaction = Braintree::Transaction._new(
        :gateway,
        :ideal_payment => {
          :ideal_payment_id => "idealpayment_abc_123",
          :ideal_transaction_id => "1150000008857321",
          :masked_iban => "12************7890",
          :bic => "RABONL2U",
          :image_url => "http://www.example.com/ideal.png"
        }
      )

      transaction.ideal_payment_details.ideal_payment_id.should == "idealpayment_abc_123"
      transaction.ideal_payment_details.ideal_transaction_id.should == "1150000008857321"
      transaction.ideal_payment_details.masked_iban.should == "12************7890"
      transaction.ideal_payment_details.bic.should == "RABONL2U"
      transaction.ideal_payment_details.image_url.should == "http://www.example.com/ideal.png"
    end

    it "sets up history attributes in status_history" do
      time = Time.utc(2010,1,14)
      transaction = Braintree::Transaction._new(
        :gateway,
        :status_history => [
          { :timestamp => time, :amount => "12.00", :transaction_source => "API",
            :user => "larry", :status => Braintree::Transaction::Status::Authorized },
          { :timestamp => Time.utc(2010,1,15), :amount => "12.00", :transaction_source => "API",
            :user => "curly", :status => "scheduled_for_settlement"}
        ])
      transaction.status_history.size.should == 2
      transaction.status_history[0].user.should == "larry"
      transaction.status_history[0].amount.should == "12.00"
      transaction.status_history[0].status.should == Braintree::Transaction::Status::Authorized
      transaction.status_history[0].transaction_source.should == "API"
      transaction.status_history[0].timestamp.should == time
      transaction.status_history[1].user.should == "curly"
    end

    it "sets up authorization_adjustments" do
      timestamp = Time.utc(2010,1,14)
      transaction = Braintree::Transaction._new(
        :gateway,
        :authorization_adjustments => [
          { :timestamp => timestamp, :processor_response_code => "1000", :processor_response_text => "Approved", :amount => "12.00", :success => true },
          { :timestamp => timestamp, :processor_response_code => "3000", :processor_response_text => "Processor Network Unavailable - Try Again", :amount => "12.34", :success => false },
        ])
      transaction.authorization_adjustments.size.should == 2
      transaction.authorization_adjustments[0].amount.should == "12.00"
      transaction.authorization_adjustments[0].success.should == true
      transaction.authorization_adjustments[0].timestamp.should == timestamp
      transaction.authorization_adjustments[0].processor_response_code.should == "1000"
      transaction.authorization_adjustments[0].processor_response_text.should == "Approved"
      transaction.authorization_adjustments[1].amount.should == "12.34"
      transaction.authorization_adjustments[1].success.should == false
      transaction.authorization_adjustments[1].timestamp.should == timestamp
      transaction.authorization_adjustments[1].processor_response_code.should == "3000"
      transaction.authorization_adjustments[1].processor_response_text.should == "Processor Network Unavailable - Try Again"
    end

    it "handles receiving custom as an empty string" do
      transaction = Braintree::Transaction._new(
        :gateway,
        :custom => "\n    "
      )
    end

    it "accepts amount as either a String or a BigDecimal" do
      Braintree::Transaction._new(:gateway, :amount => "12.34").amount.should == BigDecimal("12.34")
      Braintree::Transaction._new(:gateway, :amount => BigDecimal("12.34")).amount.should == BigDecimal("12.34")
    end

    it "blows up if amount is not a string or BigDecimal" do
      expect {
        Braintree::Transaction._new(:gateway, :amount => 12.34)
      }.to raise_error(/Argument must be a String or BigDecimal/)
    end

    it "handles nil risk_data" do
      transaction = Braintree::Transaction._new(
        :gateway,
        :risk_data => nil
      )
      transaction.risk_data.should be_nil
    end

    it "accepts network_transaction_id" do
      transaction = Braintree::Transaction._new(
        :gateway,
        :network_transaction_id => "123456789012345"
      )
      transaction.network_transaction_id.should == "123456789012345"
    end

    it "accepts network_response code and network_response_text" do
      transaction = Braintree::Transaction._new(
        :gateway,
        :network_response_code => "00",
        :network_response_text => "Successful approval/completion or V.I.P. PIN verification is successful",
      )
      expect(transaction.network_response_code).to eq("00")
      expect(transaction.network_response_text).to eq("Successful approval/completion or V.I.P. PIN verification is successful")
    end
  end

  describe "inspect" do
    it "includes the id, type, amount, status, and processed_with_network_token?" do
      transaction = Braintree::Transaction._new(
        :gateway,
        :id => "1234",
        :type => "sale",
        :amount => "100.00",
        :status => Braintree::Transaction::Status::Authorized,
        :processed_with_network_token => false,
      )
      output = transaction.inspect
      output.should include(%Q(#<Braintree::Transaction id: "1234", type: "sale", amount: "100.0", status: "authorized"))
      output.should include(%Q(processed_with_network_token?: false))
    end
  end

  describe "==" do
    it "returns true for transactions with the same id" do
      first = Braintree::Transaction._new(:gateway, :id => 123)
      second = Braintree::Transaction._new(:gateway, :id => 123)

      first.should == second
      second.should == first
    end

    it "returns false for transactions with different ids" do
      first = Braintree::Transaction._new(:gateway, :id => 123)
      second = Braintree::Transaction._new(:gateway, :id => 124)

      first.should_not == second
      second.should_not == first
    end

    it "returns false when comparing to nil" do
      Braintree::Transaction._new(:gateway, {}).should_not == nil
    end

    it "returns false when comparing to non-transactions" do
      same_id_different_object = Object.new
      def same_id_different_object.id; 123; end
      transaction = Braintree::Transaction._new(:gateway, :id => 123)
      transaction.should_not == same_id_different_object
    end
  end

  describe "new" do
    it "is protected" do
      expect do
        Braintree::Transaction.new
      end.to raise_error(NoMethodError, /protected method .new/)
    end
  end

  describe "refunded?" do
    it "is true if the transaciton has been refunded" do
      transaction = Braintree::Transaction._new(:gateway, :refund_id => "123")
      transaction.refunded?.should == true
    end

    it "is false if the transaciton has not been refunded" do
      transaction = Braintree::Transaction._new(:gateway, :refund_id => nil)
      transaction.refunded?.should == false
    end
  end

  describe "sale" do
    let(:mock_response) { {:transaction => {}}}
    let(:http_stub) { double('http_stub').as_null_object }

    RSpec::Matchers.define :skip_advanced_fraud_check_value_is do |value|
        match { |params| params[:transaction][:options][:skip_advanced_fraud_checking] == value }
    end

    it "accepts skip_advanced_fraud_checking options with value true" do
      Braintree::Http.stub(:new).and_return http_stub
      expect(http_stub).to receive(:post).with(anything, skip_advanced_fraud_check_value_is(true)).and_return(mock_response)

      Braintree::Transaction.sale(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        },
        :options => {
          :skip_advanced_fraud_checking => true
        }
      )
    end

    it "accepts skip_advanced_fraud_checking options with value false" do
      Braintree::Http.stub(:new).and_return http_stub
      expect(http_stub).to receive(:post).with(anything, skip_advanced_fraud_check_value_is(false)).and_return(mock_response)

      Braintree::Transaction.sale(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        },
        :options => {
          :skip_advanced_fraud_checking => false
        }
      )
    end

    it "doesn't include skip_advanced_fraud_checking in params if its not specified" do
      Braintree::Http.stub(:new).and_return http_stub
      expect(http_stub).to receive(:post).with(anything, skip_advanced_fraud_check_value_is(nil)).and_return(mock_response)

      Braintree::Transaction.sale(
        :amount => Braintree::Test::TransactionAmounts::Authorize,
        :credit_card => {
          :number => Braintree::Test::CreditCardNumbers::Visa,
          :expiration_date => "05/2009"
        },
        :options => {
          :submit_for_settlement => false
        }
      )
    end
  end

  describe "processed_with_network_token?" do
    it "is true if the transaction was processed with a network token" do
      transaction = Braintree::Transaction._new(:gateway, :processed_with_network_token => true)
      transaction.processed_with_network_token?.should == true
    end

    it "is false if the transaction was not processed with a network token" do
      transaction = Braintree::Transaction._new(:gateway, :processed_with_network_token => false)
      transaction.processed_with_network_token?.should == false
    end
  end
end
