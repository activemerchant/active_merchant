require 'test_helper'

class DokuNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @doku_verify = Doku::Notification.new(http_raw_data_verify)
    @doku_notify = Doku::Notification.new(http_raw_data_notify)
    @shared_key = "SHARED_KEY"
  end

  def test_accessors_notify
    assert @doku_notify.complete?
    assert_equal "Completed", @doku_notify.status
    assert_equal "ORD12345", @doku_notify.item_id
    assert_equal "165000", @doku_notify.gross
    assert_equal "IDR", @doku_notify.currency
  end

  def test_accessors_verify
    words_seed = "#{@doku_verify.gross}#{@shared_key}#{@doku_verify.item_id}"
    expected_words = Digest::SHA1.hexdigest(words_seed)

    assert @doku_verify.complete?
    assert !@doku.status
    assert_equal "000001", @doku_notify.item_id
    assert_equal "100", @doku_notify.gross
    assert_equal expected_words, @doku_verify.words
  end

  def test_type
    assert_equal 'notify', @doku_notify.type
    assert_equal 'verify', @doku_verify.type
  end

  def test_acknowledge_on_verify
    assert @doku_verify.acknowledge
  end

  def test_acknowledge_on_notify
    assert @doku_notify.acknowledge
  end

  def test_acknowledge_on_corrupt
    bad_request = Doku::Notification.new("GARBAGEPARAM=garbage")
    assert !bad_request.acknowledge
  end

  private
  def http_raw_data_notify
    "TRANSIDMERCHANT=ORD12345&AMOUNT=165000&RESULT=Success"
  end

  def http_raw_data_verify
    "STOREID=STORE0123&TRANSIDMERCHANT=000001&AMOUNT=100&WORDS=26e5fb7ec6d1e839fd68b24abb822e174a9f852a"
  end
end