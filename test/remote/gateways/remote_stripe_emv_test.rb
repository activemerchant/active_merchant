require 'test_helper'

class RemoteStripeEmvTest < Test::Unit::TestCase
  CHARGE_ID_REGEX = /ch_[a-zA-Z\d]{24}/

  def setup
    @gateway = StripeGateway.new(fixtures(:stripe))

    @amount = 100
    @emv_credit_cards = {
      uk: ActiveMerchant::Billing::CreditCard.new(icc_data: '5A08476173900101011957114761739001010119D221220117589288899F131F3137353839383930303238383030303030304F07A0000000031010500B564953412043524544495482025C008407A00000000310108A025A318E0E00000000000000001E0302031F00950542000080009A031707259B02E8009C01005F24032212315F25030907015F2A0208265F3401019F01060000000000019F02060000000001009F03060000000000009F0607A00000000310109F0702FF009F0902008C9F0D05F0400088009F0E0500100000009F0F05F0400098009F100706010A03A000009F120F4352454449544F20444520564953419F160F3132333435363738393031323334359F1A0208269F1C0831313232333334349F1E0831323334353637389F21031137269F26084A3000C111F061539F2701809F33036028C89F34031E03009F3501219F360200029F370467D5DD109F3901059F40057E0000A0019F4104000001979F4E0D54657374204D65726368616E749F110101DF834F0F434842313136373235303030343439DF83620100'),
      us: ActiveMerchant::Billing::CreditCard.new(icc_data: '5A08476173900101011957114761739001010119D221220117589288899F131F3137353839383930303238383030303030304F07A0000000031010500B564953412043524544495482025C008407A00000000310108A025A318E0E00000000000000001E0302031F00950542000080009A031707259B02E8009C01005F24032212315F25030907015F2A0208405F3401019F01060000000000019F02060000000001009F03060000000000009F0607A00000000310109F0702FF009F0902008C9F0D05F0400088009F0E0500100000009F0F05F0400098009F100706010A03A000009F120F4352454449544F20444520564953419F160F3132333435363738393031323334359F1A0208409F1C0831313232333334349F1E0831323334353637389F21031137269F26084A3000C111F061539F2701809F33036028C89F34031E03009F3501219F360200029F370467D5DD109F3901059F40057E0000A0019F4104000001979F4E0D54657374204D65726368616E749F110101DF834F0F434842313136373235303030343439DF83620100'),
      contactless: ActiveMerchant::Billing::CreditCard.new(icc_data: '5A08476173900101011957114761739001010119D22122011758928889500D5649534120454C454354524F4E5F20175649534120434445542032312F434152443035202020205F2A0208405F340111820200008407A00000000320109A031505119C01009F02060000000006009F0607A00000000320109F090200019F100706011103A000009F1A0200569F1C0831323334353637389F1E0831303030333236389F260852A5A96394EDA96D9F2701809F3303E0B8C89F3501229F360200069F3704A4428D7A9F410400000289')
    }

    @options = {
      :currency => 'USD',
      :description => 'ActiveMerchant Test Purchase',
      :email => 'wow@example.com'
    }

    #  This capture hex says that the payload is a transaction cryptogram (TC) but does not
    # provide the actual cryptogram. This will only work in test mode and would cause real
    # cards to be declined.
    @capture_options = { icc_data: '9F270140' } 
  end

  # for EMV contact transactions, it's advised to do a separate auth + capture
  # to satisfy the EMV chip's transaction flow, but this works as a legal
  # API call. You shouldn't use it in a real EMV implementation, though.
  def test_successful_purchase_with_emv_credit_card_in_uk
    assert response = @gateway.purchase(@amount, @emv_credit_cards[:uk], @options)
    assert_success response
    assert_equal 'charge', response.params['object']
    assert response.params['paid']
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  # perform separate auth & capture rather than a purchase in practice for the
  # reasons mentioned above.
  def test_successful_purchase_with_emv_credit_card_in_us
    assert response = @gateway.purchase(@amount, @emv_credit_cards[:us], @options)
    assert_success response
    assert_equal 'charge', response.params['object']
    assert response.params['paid']
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_successful_purchase_with_quickchip_credit_card_in_us
    credit_card = @emv_credit_cards[:us]
    credit_card.read_method = 'contact_quickchip'
    assert response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal 'charge', response.params['object']
    assert response.params['captured']
    assert response.params['paid']
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  # For EMV contactless transactions, generally a purchase is preferred since
  # a TC is typically generated at the point of sale.
  def test_successful_purchase_with_emv_contactless_credit_card
    emv_credit_card = @emv_credit_cards[:contactless]
    emv_credit_card.read_method = 'contactless'
    assert response = @gateway.purchase(@amount, emv_credit_card, @options)
    assert_success response
    assert_equal 'charge', response.params['object']
    assert response.params['paid']
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_authorization_and_capture_with_emv_credit_card_in_uk
    assert authorization = @gateway.authorize(@amount, @emv_credit_cards[:uk], @options)
    assert_success authorization
    assert authorization.emv_authorization, 'Authorization should contain emv_authorization containing the EMV ARPC'
    refute authorization.params['captured']

    assert capture = @gateway.capture(@amount, authorization.authorization, @capture_options)
    assert_success capture
    assert capture.emv_authorization, 'Capture should contain emv_authorization containing the EMV TC'
  end

  def test_authorization_and_capture_with_emv_credit_card_in_us
    assert authorization = @gateway.authorize(@amount, @emv_credit_cards[:us], @options)
    assert_success authorization
    assert authorization.emv_authorization, 'Authorization should contain emv_authorization containing the EMV ARPC'
    refute authorization.params['captured']

    assert capture = @gateway.capture(@amount, authorization.authorization, @capture_options)
    assert_success capture
    assert capture.emv_authorization, 'Capture should contain emv_authorization containing the EMV TC'
  end

  def test_authorization_and_capture_of_online_pin_with_emv_credit_card_in_us
    emv_credit_card = @emv_credit_cards[:us]
    emv_credit_card.encrypted_pin_cryptogram = '8b68af72199529b8'
    emv_credit_card.encrypted_pin_ksn = 'ffff0102628d12000001'

    assert authorization = @gateway.authorize(@amount, emv_credit_card, @options)
    assert_success authorization
    assert authorization.emv_authorization, 'Authorization should contain emv_authorization containing the EMV ARPC'
    refute authorization.params['captured']

    assert capture = @gateway.capture(@amount, authorization.authorization, @capture_options)
    assert_success capture
    assert capture.emv_authorization, 'Capture should contain emv_authorization containing the EMV TC'
  end

  def test_authorization_and_void_with_emv_credit_card_in_us
    assert authorization = @gateway.authorize(@amount, @emv_credit_cards[:us], @options)
    assert_success authorization
    assert authorization.emv_authorization, 'Authorization should contain emv_authorization containing the EMV ARPC'
    refute authorization.params['captured']

    assert void = @gateway.void(authorization.authorization)
    assert_success void
  end

  def test_authorization_and_void_with_emv_credit_card_in_uk
    assert authorization = @gateway.authorize(@amount, @emv_credit_cards[:uk], @options)
    assert_success authorization
    assert authorization.emv_authorization, 'Authorization should contain emv_authorization containing the EMV ARPC'
    refute authorization.params['captured']

    assert void = @gateway.void(authorization.authorization)
    assert_success void
  end

  def test_purchase_and_void_with_emv_contactless_credit_card
    emv_credit_card = @emv_credit_cards[:contactless]
    emv_credit_card.read_method = 'contactless'
    assert purchase = @gateway.purchase(@amount, emv_credit_card, @options)
    assert_success purchase
    assert purchase.emv_authorization, 'Authorization should contain emv_authorization containing the EMV ARPC'
    assert purchase.params['captured']
    assert purchase.params['paid']

    assert void = @gateway.void(purchase.authorization)
    assert_success void
  end

  def test_authorization_emv_credit_card_in_us_with_metadata
    assert authorization = @gateway.authorize(@amount, @emv_credit_cards[:us], @options.merge({:metadata => {:this_is_a_random_key_name => 'with a random value', :i_made_up_this_key_too => 'canyoutell'}, :order_id => '42', :email => 'foo@wonderfullyfakedomain.com'}))
    assert_success authorization
  end
end
