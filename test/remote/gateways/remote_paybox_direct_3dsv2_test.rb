# encoding: utf-8

require 'test_helper'

class RemotePayboxDirect3DSV2Test < Test::Unit::TestCase
  def setup
    fixtures = fixtures(:paybox_direct)
    @gateway = PayboxDirectGateway.new(fixtures)

    @amount = 100
    @credit_card = credit_card(fixtures[:credit_card_ok_3dsv2])
    @declined_card = credit_card(fixtures[:credit_card_nok_3dsv2])
    @unenrolled_card = credit_card(fixtures[:credit_card_ok_3dsv2_not_enrolled])

    @options = {
      order_id: '1999',
      merchant_name: 'Merchant',
      billing_address: address,
      shipping_address: address,
      description: 'Store Purchase',
      ip: '127.0.0.1',
      three_d_secure: {
        version: '2.1.0',
        eci: '02',
        cavv: 'MTIzNDU2Nzg5MDEyMzQ1Njc4OTA=',
        xid: '00000000000000000501',
        cavv_algorithm: '1',
        ds_transaction_id: 'fe4e1fb7-008e-46d5-89b1-505e68a53635',
        acs_transaction_id: '81256d53-3f56-443c-a5c2-bc030ffc5d56',
        authentication_response_status: 'Y',
      },
      line_items: [
        {
          quantity: 2,
        },
        {
          quantity: 1,
        }
      ]
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'The transaction was approved', response.message
  end

  def test_successful_purchase_other_eci
    options = @options
    options[:three_d_secure][:eci] = '05'

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'The transaction was approved', response.message
  end

  def test_successful_unenrolled_3ds_purchase
    assert response = @gateway.purchase(@amount, @unenrolled_card, @options)
    assert_success response
    assert_equal 'The transaction was approved', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'The transaction was approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization, order_id: '1')
    assert_success capture
  end

  def test_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal 'The transaction was approved', purchase.message
    assert purchase.authorization
    # Paybox requires you to remember the expiration date
    assert void = @gateway.void(purchase.authorization, order_id: '1', amount: @amount)
    assert_equal 'The transaction was approved', void.message
    assert_success void
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '', order_id: '1')
    assert_failure response
    assert_equal 'Mandatory values missing keyword:13 Type:1', response.message
  end

  def test_purchase_and_partial_credit
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal 'The transaction was approved', purchase.message
    assert purchase.authorization
    assert credit = @gateway.refund(@amount / 2, purchase.authorization, order_id: '1')
    assert_equal 'The transaction was approved', credit.message
    assert_success credit
  end

  def test_successful_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, order_id: '1')
    assert_success refund
  end

  def test_partial_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount / 2, purchase.authorization, order_id: '1')
    assert_success refund
  end

  def test_failed_refund
    refund = @gateway.refund(@amount, '', order_id: '2')
    assert_failure refund
    assert_equal 'Mandatory values missing keyword:13 Type:13', refund.message
  end

  def test_failed_purchase_invalid_eci
    options = @options
    options[:three_d_secure][:eci] = '00'

    assert purchase = @gateway.purchase(@amount, @credit_card, options)
    assert_failure purchase
    assert_equal "Signature PARes 3DS invalide", purchase.message
  end

  def test_failed_purchase_invalid_cavv
    options = @options
    options[:three_d_secure][:cavv] = 'jJ81HADVRtXfCBATEp01CJUAAAAVZQGY='

    assert purchase = @gateway.purchase(@amount, @credit_card, options)
    assert_failure purchase
    assert_equal 'Some values exceed max length', purchase.message
  end

  def test_failed_purchase_invalid_ds_transaction_id
    options = @options
    options[:three_d_secure][:ds_transaction_id] = 'INVALIDDSTID'

    assert purchase = @gateway.purchase(@amount, @credit_card, options)
    assert_failure purchase
    assert_equal "PAYBOX : Trame re\xE7ue invalide".force_encoding('ASCII-8BIT'), purchase.message
  end

  def test_failed_purchase_invalid_acs_transaction_id
    options = @options
    options[:three_d_secure][:acs_transaction_id] = 'INVALIDACSTID'
    assert purchase = @gateway.purchase(@amount, @credit_card, options)
    assert_failure purchase
    assert_equal "PAYBOX : Trame re\xE7ue invalide".force_encoding('ASCII-8BIT'), purchase.message
  end

  def test_failed_purchase_longer_merchant_name
    options = @options
    options[:merchant_name] = 'MerchantNameLongerThanMaxLengthAllowedByApi'
    assert purchase = @gateway.purchase(@amount, @credit_card, options)
    assert_failure purchase
    assert_equal "Some values exceed max length".force_encoding('ASCII-8BIT'), purchase.message
  end

  def test_unsuccessful_purchase_unauthentified_response_status
    options = @options
    options[:three_d_secure][:authentication_response_status] = 'N'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Statut PARes 3DS invalide".force_encoding('ASCII-8BIT'), response.message
  end

  def test_unsuccessful_purchase_invalid_bearer
    options = @options
    options[:ERRORCODETEST] = '00114'
    assert response = @gateway.purchase(@amount, @declined_card, options)
    assert_failure response
    assert_equal "Num\xE9ro de porteur invalide".force_encoding('ASCII-8BIT'), response.message
  end

  def test_unsuccessful_purchase_unknown_card_emitter
    options = @options
    options[:ERRORCODETEST] = '00115'
    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_failure response
    assert_equal "Emetteur de carte inconnu".force_encoding('ASCII-8BIT'), response.message
  end

  def test_unsuccessful_purchase_failed_bank_authentication
    options = @options
    options[:ERRORCODETEST] = '00189'
    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_failure response
    assert_equal "*** Code erreur en retour de la banque inconnu ***".force_encoding('ASCII-8BIT'), response.message
  end
end
