require 'test_helper'

class RemoteStripeEmvTest < Test::Unit::TestCase
  def setup
    @gateway = StripeGateway.new(fixtures(:stripe))

    @amount = 100
    @emv_credit_cards = {
      uk: ActiveMerchant::Billing::CreditCard.new(icc_data: '500B56495341204352454449545F201A56495341204143515549524552205445535420434152442030315F24031512315F280208405F2A0208265F300202015F34010182025C008407A0000000031010950502000080009A031408259B02E8009C01009F02060000000734499F03060000000000009F0607A00000000310109F0902008C9F100706010A03A080009F120F4352454449544F20444520564953419F1A0208269F1C0831373030303437309F1E0831373030303437309F2608EB2EC0F472BEA0A49F2701809F3303E0B8C89F34031E03009F3501229F360200C39F37040A27296F9F4104000001319F4502DAC5DFAE5711476173FFFFFF0119D15122011758989389DFAE5A08476173FFFFFF011957114761739001010119D151220117589893895A084761739001010119'),
      us: ActiveMerchant::Billing::CreditCard.new(icc_data: '50074D41455354524F571167999989000018123D25122200835506065A0967999989000018123F5F20134D54495032362D204D41455354524F203132415F24032512315F280200565F2A0208405F300202205F340101820278008407A0000000043060950500000080009A031504219B02E8009C01009F02060000000010009F03060000000000009F0607A00000000430609F090200029F10120210A7800F040000000000000000000000FF9F12074D61657374726F9F1A0208409F1C0831303030333331369F1E0831303030333331369F2608460245B808BCA1369F2701809F3303E0B8C89F34034403029F3501229F360200279F3704EA2C3A7A9F410400000094DF280104DFAE5711679999FFFFFFF8123D2512220083550606DFAE5A09679999FFFFFFF8123F'),
      contactless: ActiveMerchant::Billing::CreditCard.new(icc_data: '500D5649534120454C454354524F4E5F20175649534120434445542032312F434152443035202020205F2A0208405F340111820200008407A00000000320109A031505119C01009F02060000000006959F0607A00000000320109F090200019F100706011103A000009F1A0200569F1C0831323334353637389F1E0831303030333236389F260852A5A96394EDA96D9F2701809F3303E0B8C89F3501229F360200069F3704A4428D7A9F410400000289DF280100DF30020301DFAE021885D6E511F8844CEA0DC72883180AC081AF4593A8A3C5FDD8DFAE030AFFFF0102628D1100005EDFAE5712476173FFFFFFFFF2234D151220114524040FDFAE021892FC2C940487F43AC64AB3DFD54C7B72F445FE409D80FDF5DFAE030AFFFF0102628D1100005F')
    }

    @options = {
      :currency => "USD",
      :description => 'ActiveMerchant Test Purchase',
      :email => 'wow@example.com'
    }
  end

  # for EMV contact transactions, it's advised to do a separate auth + capture
  # to satisfy the EMV chip's transaction flow, but this works as a legal
  # API call. You shouldn't use it in a real EMV implementation, though.
  def test_successful_purchase_with_emv_credit_card_in_uk
    @gateway = StripeGateway.new(fixtures(:stripe_emv_uk))
    assert response = @gateway.purchase(@amount, @emv_credit_cards[:uk], @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  # perform separate auth & capture rather than a purchase in practice for the
  # reasons mentioned above.
  def test_successful_purchase_with_emv_credit_card_in_us
    @gateway = StripeGateway.new(fixtures(:stripe_emv_us))
    assert response = @gateway.purchase(@amount, @emv_credit_cards[:us], @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  # For EMV contactless transactions, generally a purchase is preferred since
  # a TC is typically generated at the point of sale.
  def test_successful_purchase_with_emv_contactless_credit_card
    @gateway = StripeGateway.new(fixtures(:stripe_emv_us))
    emv_credit_card = @emv_credit_cards[:contactless]
    emv_credit_card.contactless = true
    assert response = @gateway.purchase(@amount, emv_credit_card, @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_authorization_and_capture_with_emv_credit_card_in_uk
    @gateway = StripeGateway.new(fixtures(:stripe_emv_uk))
    assert authorization = @gateway.authorize(@amount, @emv_credit_cards[:uk], @options)
    assert_success authorization
    assert authorization.emv_authorization, "Authorization should contain emv_authorization containing the EMV ARPC"
    refute authorization.params["captured"]

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert capture.emv_authorization, "Capture should contain emv_authorization containing the EMV TC"
  end

  def test_authorization_and_capture_with_emv_credit_card_in_us
    @gateway = StripeGateway.new(fixtures(:stripe_emv_us))
    assert authorization = @gateway.authorize(@amount, @emv_credit_cards[:us], @options)
    assert_success authorization
    assert authorization.emv_authorization, "Authorization should contain emv_authorization containing the EMV ARPC"
    refute authorization.params["captured"]

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert capture.emv_authorization, "Capture should contain emv_authorization containing the EMV TC"
  end

  def test_authorization_and_capture_of_online_pin_with_emv_credit_card_in_us
    @gateway = StripeGateway.new(fixtures(:stripe_emv_us))
    emv_credit_card = @emv_credit_cards[:us]
    emv_credit_card.encrypted_pin_cryptogram = "8b68af72199529b8"
    emv_credit_card.encrypted_pin_ksn = "ffff0102628d12000001"

    assert authorization = @gateway.authorize(@amount, emv_credit_card, @options)
    assert_success authorization
    assert authorization.emv_authorization, "Authorization should contain emv_authorization containing the EMV ARPC"
    refute authorization.params["captured"]

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert capture.emv_authorization, "Capture should contain emv_authorization containing the EMV TC"
  end

  def test_authorization_and_capture_with_emv_contactless_credit_card
    @gateway = StripeGateway.new(fixtures(:stripe_emv_us))
    emv_credit_card = @emv_credit_cards[:contactless]
    emv_credit_card.contactless = true
    assert authorization = @gateway.authorize(@amount, emv_credit_card, @options)
    assert_success authorization
    assert authorization.emv_authorization, "Authorization should contain emv_authorization containing the EMV ARPC"
    refute authorization.params["captured"]

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert capture.emv_authorization, "Capture should contain emv_authorization containing the EMV TC"
  end

  def test_authorization_and_void_with_emv_credit_card_in_us
    @gateway = StripeGateway.new(fixtures(:stripe_emv_us))
    assert authorization = @gateway.authorize(@amount, @emv_credit_cards[:us], @options)
    assert_success authorization
    assert authorization.emv_authorization, "Authorization should contain emv_authorization containing the EMV ARPC"
    refute authorization.params["captured"]

    assert void = @gateway.void(authorization.authorization)
    assert_success void
  end

  def test_authorization_and_void_with_emv_credit_card_in_uk
    @gateway = StripeGateway.new(fixtures(:stripe_emv_uk))
    assert authorization = @gateway.authorize(@amount, @emv_credit_cards[:uk], @options)
    assert_success authorization
    assert authorization.emv_authorization, "Authorization should contain emv_authorization containing the EMV ARPC"
    refute authorization.params["captured"]

    assert void = @gateway.void(authorization.authorization)
    assert_success void
  end

  def test_authorization_and_void_with_emv_contactless_credit_card
    @gateway = StripeGateway.new(fixtures(:stripe_emv_us))
    emv_credit_card = @emv_credit_cards[:contactless]
    emv_credit_card.contactless = true
    assert authorization = @gateway.authorize(@amount, emv_credit_card, @options)
    assert_success authorization
    assert authorization.emv_authorization, "Authorization should contain emv_authorization containing the EMV ARPC"
    refute authorization.params["captured"]

    assert void = @gateway.void(authorization.authorization)
    assert_success void
  end

  def test_authorization_emv_credit_card_in_us_with_metadata
    @gateway = StripeGateway.new(fixtures(:stripe_emv_us))
    assert authorization = @gateway.authorize(@amount, @emv_credit_cards[:us], @options.merge({:metadata => {:this_is_a_random_key_name => 'with a random value', :i_made_up_this_key_too => 'canyoutell'}, :order_id => "42", :email => "foo@wonderfullyfakedomain.com"}))
    assert_success authorization
  end
end
