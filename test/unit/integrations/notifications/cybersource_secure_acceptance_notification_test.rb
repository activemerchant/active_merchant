require 'test_helper'

class CybersourceSecureAcceptanceNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @cybersource_secure_acceptance = CybersourceSecureAcceptance::Notification.new(http_raw_data, credential3: 'secret_key')
  end

  def test_accessors
    assert @cybersource_secure_acceptance.complete?
    assert_equal "ACCEPT", @cybersource_secure_acceptance.status
    assert_equal "3993692250820176195663", @cybersource_secure_acceptance.transaction_id
    assert_equal "order-500", @cybersource_secure_acceptance.item_id
    assert_equal "5.00", @cybersource_secure_acceptance.gross
    assert_equal "USD", @cybersource_secure_acceptance.currency
    assert_equal DateTime.parse('Thu, 06 May 2014 09:40:27 +0000'), @cybersource_secure_acceptance.received_at
    assert_equal 'Visa', @cybersource_secure_acceptance.card_brand
    assert @cybersource_secure_acceptance.test?
  end

  def test_compositions
    assert_equal Money.new(500, 'USD'), @cybersource_secure_acceptance.amount
  end

  def test_authorization
    @cybersource_secure_acceptance = CybersourceSecureAcceptance::Notification.new(http_raw_data_with_payment_token, credential3: 'secret_key')
    assert_equal 'order-500;3993692250820176195663;5551234567890123456789', @cybersource_secure_acceptance.authorization
  end

  def test_invalid_authorization
    assert_raise ArgumentError do
      @cybersource_secure_acceptance.authorization
    end
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement
    assert @cybersource_secure_acceptance.acknowledge
  end

  def test_failed_acknnowledgement
    @cybersource_secure_acceptance = CybersourceSecureAcceptance::Notification.new(http_raw_data, :credential3 => "bad_secret_key")
    assert !@cybersource_secure_acceptance.acknowledge
  end

  def test_respond_to_acknowledge
    assert @cybersource_secure_acceptance.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    "utf8=%E2%9C%93&req_bill_to_address_country=CA&auth_avs_code=Y&req_card_number=xxxxxxxxxxxx1111&req_card_expiry_date=01-2016&decision=ACCEPT&req_bill_to_address_state=Yorkshire&signed_field_names=transaction_id%2Cdecision%2Creq_access_key%2Creq_profile_id%2Creq_transaction_uuid%2Creq_transaction_type%2Creq_reference_number%2Creq_amount%2Creq_currency%2Creq_locale%2Creq_payment_method%2Creq_bill_to_forename%2Creq_bill_to_surname%2Creq_bill_to_email%2Creq_bill_to_address_line1%2Creq_bill_to_address_city%2Creq_bill_to_address_state%2Creq_bill_to_address_country%2Creq_bill_to_address_postal_code%2Creq_card_number%2Creq_card_type%2Creq_card_expiry_date%2Cmessage%2Creason_code%2Cauth_avs_code%2Cauth_avs_code_raw%2Cauth_response%2Cauth_amount%2Cauth_code%2Cauth_trans_ref_no%2Cauth_time%2Csigned_field_names%2Csigned_date_time&req_payment_method=card&req_transaction_type=authorization&auth_code=831000&signature=Q4OIexuy7PPeZqs3aFM8w3d5h8aBTHRB44VOJvomflI%3D&req_locale=en&req_bill_to_address_postal_code=LS27EE&reason_code=100&req_bill_to_address_line1=1+My+Street&req_card_type=001&auth_amount=5.00&req_bill_to_address_city=Leeds&signed_date_time=2014-05-06T09%3A40%3A27Z&req_currency=USD&req_reference_number=order-500&auth_avs_code_raw=Y&transaction_id=3993692250820176195663&req_amount=5.00&auth_time=2014-05-06T094027Z&message=Request+was+processed+successfully.&auth_response=00&req_profile_id=SAMPLE1&req_transaction_uuid=3ca30b6f20815bbc4e7981b1bddc2a39&auth_trans_ref_no=WWNTNU4WCGQ4&req_bill_to_surname=Fauser&req_bill_to_forename=Cody&req_bill_to_email=example%40example.com&req_access_key=accesskey"
  end

  def http_raw_data_with_payment_token
    "utf8=%E2%9C%93&req_bill_to_address_country=CA&auth_avs_code=Y&req_card_number=xxxxxxxxxxxx1111&req_card_expiry_date=01-2016&decision=ACCEPT&req_bill_to_address_state=Yorkshire&signed_field_names=transaction_id%2Cdecision%2Creq_access_key%2Creq_profile_id%2Creq_transaction_uuid%2Creq_transaction_type%2Creq_reference_number%2Creq_amount%2Creq_currency%2Creq_locale%2Creq_payment_method%2Creq_bill_to_forename%2Creq_bill_to_surname%2Creq_bill_to_email%2Creq_bill_to_address_line1%2Creq_bill_to_address_city%2Creq_bill_to_address_state%2Creq_bill_to_address_country%2Creq_bill_to_address_postal_code%2Creq_card_number%2Creq_card_type%2Creq_card_expiry_date%2Cmessage%2Creason_code%2Cauth_avs_code%2Cauth_avs_code_raw%2Cauth_response%2Cauth_amount%2Cauth_code%2Cauth_trans_ref_no%2Cauth_time%2Csigned_field_names%2Csigned_date_time&req_payment_method=card&req_transaction_type=authorization&auth_code=831000&signature=Q4OIexuy7PPeZqs3aFM8w3d5h8aBTHRB44VOJvomflI%3D&req_locale=en&req_bill_to_address_postal_code=LS27EE&reason_code=100&req_bill_to_address_line1=1+My+Street&req_card_type=001&auth_amount=5.00&req_bill_to_address_city=Leeds&signed_date_time=2014-05-06T09%3A40%3A27Z&req_currency=USD&req_reference_number=order-500&auth_avs_code_raw=Y&transaction_id=3993692250820176195663&req_amount=5.00&auth_time=2014-05-06T094027Z&message=Request+was+processed+successfully.&auth_response=00&req_profile_id=SAMPLE1&req_transaction_uuid=3ca30b6f20815bbc4e7981b1bddc2a39&auth_trans_ref_no=WWNTNU4WCGQ4&req_bill_to_surname=Fauser&req_bill_to_forename=Cody&req_bill_to_email=example%40example.com&req_access_key=accesskey&payment_token=5551234567890123456789"
  end
end
