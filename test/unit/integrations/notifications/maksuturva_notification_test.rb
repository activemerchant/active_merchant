require 'test_helper'

class MaksuturvaNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @Maksuturva = Maksuturva::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @Maksuturva.complete?
    assert_equal "PAID", @Maksuturva.status
    assert_equal "2", @Maksuturva.transaction_id
    assert_equal "200,00", @Maksuturva.gross
    assert_equal "EUR", @Maksuturva.currency
  end

  def test_acknowledgement
    assert @Maksuturva.acknowledge("11223344556677889900")
  end

  def test_faulty_acknowledgement
    @Maksuturva = Maksuturva::Notification.new({"pmt_action"=>"NEW_PAYMENT_EXTENDED", "pmt_version"=>"0004", "pmt_id"=>"2", "pmt_reference"=>"134663", "pmt_amount"=>"200,00", "pmt_currency"=>"EUR", "pmt_sellercosts"=>"0,00", "pmt_paymentmethod"=>"FI01", "pmt_escrow"=>"N", "pmt_hash"=>"BDF4F41FA194612017CBE13CF7670971"})
    assert_equal false, @Maksuturva.acknowledge("11223344556677889900")
  end

  def test_respond_to_acknowledge
    assert @Maksuturva.respond_to?(:acknowledge)
  end

  private

  def http_raw_data
    {"pmt_action"=>"NEW_PAYMENT_EXTENDED", "pmt_version"=>"0004", "pmt_id"=>"2", "pmt_reference"=>"134662", "pmt_amount"=>"200,00", "pmt_currency"=>"EUR", "pmt_sellercosts"=>"0,00", "pmt_paymentmethod"=>"FI01", "pmt_escrow"=>"N", "pmt_hash"=>"BDF4F41FA194612017CBE13CF7670971"}
  end
end
