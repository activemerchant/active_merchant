require File.expand_path(File.dirname(__FILE__) + "/../../spec_helper")

describe Braintree::Transaction::PayPalDetails do
  describe "initialize" do
    it "sets all fields" do
      details = Braintree::Transaction::PayPalDetails.new(
        :authorization_id => "id",
        :capture_id => "capture-id",
        :custom_field => "custom-field",
        :debug_id => "debug-id",
        :description => "description",
        :image_url => "www.image.com",
        :implicitly_vaulted_payment_method_global_id => "global-id",
        :implicitly_vaulted_payment_method_token => "payment-method-token",
        :payee_email => "payee@example.com",
        :payee_id => "payee-id",
        :payer_email => "payer@example.com",
        :payer_first_name => "Grace",
        :payer_id => "payer-id",
        :payer_last_name => "Hopper",
        :payer_status =>"status",
        :payment_id => "payment-id",
        :refund_from_transaction_fee_amount => "1.00",
        :refund_from_transaction_fee_currency_iso_code => "123",
        :refund_id => "refund-id",
        :seller_protection_status => "seller-protection-status",
        :token => "token",
        :transaction_fee_amount => "2.00",
        :transaction_fee_currency_iso_code => "123"
      )

      expect(details.authorization_id).to eq("id")
      expect(details.capture_id).to eq("capture-id")
      expect(details.custom_field).to eq("custom-field")
      expect(details.debug_id).to eq("debug-id")
      expect(details.description).to eq("description")
      expect(details.image_url).to eq("www.image.com")
      expect(details.implicitly_vaulted_payment_method_global_id).to eq("global-id")
      expect(details.implicitly_vaulted_payment_method_token).to eq("payment-method-token")
      expect(details.payee_email).to eq("payee@example.com")
      expect(details.payee_id).to eq("payee-id")
      expect(details.payer_email).to eq("payer@example.com")
      expect(details.payer_first_name).to eq("Grace")
      expect(details.payer_id).to eq("payer-id")
      expect(details.payer_last_name).to eq("Hopper")
      expect(details.payer_status).to eq("status")
      expect(details.payment_id).to eq("payment-id")
      expect(details.refund_from_transaction_fee_amount).to eq("1.00")
      expect(details.refund_from_transaction_fee_currency_iso_code).to eq("123")
      expect(details.refund_id).to eq("refund-id")
      expect(details.seller_protection_status).to eq("seller-protection-status")
      expect(details.token).to eq("token")
      expect(details.transaction_fee_amount).to eq("2.00")
      expect(details.transaction_fee_currency_iso_code).to eq("123")
    end
  end
end
