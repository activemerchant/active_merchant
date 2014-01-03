require 'test_helper'

class DokuNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @shared_key = "SHARED_KEY"
    @transidmerchant = "000001"
    @amount = "100"
    @words = Digest::SHA1.hexdigest("#{@amount}#{@shared_key}#{@transidmerchant}")

    @doku_verify = Doku::Notification.new(http_raw_data_verify, :credential2 => @shared_key)
    @doku_notify = Doku::Notification.new(http_raw_data_notify, :credential2 => @shared_key)
  end

  def test_accessors_notify
    assert @doku_notify.complete?, "should be marked complete"

    assert_equal @transidmerchant,  @doku_notify.item_id
    assert_equal @amount,           @doku_notify.gross
    assert_equal "Completed",       @doku_notify.status
    assert_equal "IDR",             @doku_notify.currency
  end

  def test_accessors_verify
    words_seed = "#{@doku_verify.gross}#{@shared_key}#{@doku_verify.item_id}"
    expected_words = Digest::SHA1.hexdigest(words_seed)

    assert_equal @transidmerchant,  @doku_notify.item_id
    assert_equal @amount,           @doku_notify.gross
    assert_equal expected_words,    @doku_verify.words
  end

  def test_type
    assert_equal 'notify', @doku_notify.type
    assert_equal 'verify', @doku_verify.type
  end

  def test_acknowledge_on_verify
    assert @doku_verify.acknowledge, "should successfully acknowledge"
  end

  def test_acknowledge_on_notify
    assert @doku_notify.acknowledge, "should successfully acknowledge"
  end

  def test_acknowledge_on_corrupt
    bad_request = Doku::Notification.new("GARBAGEPARAM=garbage")
    assert !bad_request.acknowledge, "should not acknowledge"
  end

  private
  def http_raw_data_notify
    "TRANSIDMERCHANT=#{@transidmerchant}&AMOUNT=#{@amount}&RESULT=Success"
  end

  def http_raw_data_verify
    "STOREID=STORE0123&TRANSIDMERCHANT=#{@transidmerchant}&AMOUNT=#{@amount}&WORDS=#{@words}"
  end
end