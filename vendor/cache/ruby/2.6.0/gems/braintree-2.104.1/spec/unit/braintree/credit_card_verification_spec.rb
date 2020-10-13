require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::CreditCardVerification do
  describe "inspect" do
    it "is better than the default inspect" do
      verification = Braintree::CreditCardVerification._new(
        :status => "verified",
        :amount => "12.45",
        :currency_iso_code => "USD",
        :avs_error_response_code => "I",
        :avs_postal_code_response_code => "I",
        :avs_street_address_response_code => "I",
        :cvv_response_code => "I",
        :processor_response_code => "2000",
        :processor_response_text => "Do Not Honor",
        :merchant_account_id => "some_id",
        :network_response_code => "05",
        :network_response_text => "Do not Honor",
      )

      verification.inspect.should == %(#<Braintree::CreditCardVerification status: "verified", processor_response_code: "2000", processor_response_text: "Do Not Honor", amount: "12.45", currency_iso_code: "USD", cvv_response_code: "I", avs_error_response_code: "I", avs_postal_code_response_code: "I", avs_street_address_response_code: "I", network_response_code: "05", network_response_text: "Do not Honor", merchant_account_id: "some_id", gateway_rejection_reason: nil, id: nil, credit_card: nil, billing: nil, created_at: nil>)
    end

    it "has a status" do
      verification = Braintree::CreditCardVerification._new(
        :status => "verified",
        :avs_error_response_code => "I",
        :avs_postal_code_response_code => "I",
        :avs_street_address_response_code => "I",
        :cvv_response_code => "I",
        :processor_response_code => "2000",
        :processor_response_text => "Do Not Honor",
        :merchant_account_id => "some_id"
      )

      verification.status.should == Braintree::CreditCardVerification::Status::Verified
    end
  end

  it "accepts amount as either a String or BigDecimal" do
    Braintree::CreditCardVerification._new(:amount => "12.34").amount.should == BigDecimal("12.34")
    Braintree::CreditCardVerification._new(:amount => BigDecimal("12.34")).amount.should == BigDecimal("12.34")
  end

  it "accepts network_transaction_id" do
    verification = Braintree::CreditCardVerification._new(
      :network_transaction_id => "123456789012345"
    )
    expect(verification.network_transaction_id).to eq "123456789012345"
  end

  describe "self.create" do
    it "rejects invalid parameters" do
      expect do
        Braintree::CreditCardVerification.create(:invalid_key => 4, :credit_card => {:number => "number"})
      end.to raise_error(ArgumentError, "invalid keys: invalid_key")
    end

    it "rejects parameters that are only valid for 'payment methods create'" do
      expect do
        Braintree::CreditCardVerification.create(:credit_card => {:options => {:verify_card => true}})
      end.to raise_error(ArgumentError, "invalid keys: credit_card[options][verify_card]")
    end
  end

  describe "self.find" do
    it "raises error if passed empty string" do
      expect do
        Braintree::CreditCardVerification.find("")
      end.to raise_error(ArgumentError)
    end

    it "raises error if passed empty string wth space" do
      expect do
        Braintree::CreditCardVerification.find(" ")
      end.to raise_error(ArgumentError)
    end

    it "raises error if passed nil" do
      expect do
        Braintree::CreditCardVerification.find(nil)
      end.to raise_error(ArgumentError)
    end
  end

  describe "==" do
    it "returns true for verifications with the same id" do
      first = Braintree::CreditCardVerification._new(:id => 123)
      second = Braintree::CreditCardVerification._new(:id => 123)

      first.should == second
      second.should == first
    end

    it "returns false for verifications with different ids" do
      first = Braintree::CreditCardVerification._new(:id => 123)
      second = Braintree::CreditCardVerification._new(:id => 124)

      first.should_not == second
      second.should_not == first
    end

    it "returns false when comparing to nil" do
      Braintree::CreditCardVerification._new({}).should_not == nil
    end

    it "returns false when comparing to non-verifications" do
      same_id_different_object = Object.new
      def same_id_different_object.id; 123; end
      verification = Braintree::CreditCardVerification._new(:id => 123)
      verification.should_not == same_id_different_object
    end
  end

  describe "risk_data" do
    it "initializes a RiskData object" do
      verification = Braintree::CreditCardVerification._new(:risk_data => {
        :id => "123",
        :decision => "WOO YOU WON $1000 dollars",
        :device_data_captured => true,
        :fraud_service_provider => "kount"
      })

      verification.risk_data.id.should == "123"
      verification.risk_data.decision.should == "WOO YOU WON $1000 dollars"
      verification.risk_data.device_data_captured.should == true
      verification.risk_data.fraud_service_provider.should == "kount"
    end

    it "handles a nil risk_data" do
      verification = Braintree::CreditCardVerification._new(:risk_data => nil)
      verification.risk_data.should be_nil
    end
  end

  describe "network responses" do
    it "accepts network_response_code and network_response_text" do
      verification = Braintree::CreditCardVerification._new(
        :network_response_code => "00",
        :network_response_text => "Successful approval/completion or V.I.P. PIN verification is successful",
      )

      expect(verification.network_response_code).to eq("00")
      expect(verification.network_response_text).to eq("Successful approval/completion or V.I.P. PIN verification is successful")
    end
  end
end
