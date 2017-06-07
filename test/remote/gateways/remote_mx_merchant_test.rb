require 'test_helper'

class RemoteMxMerchantTest < Test::Unit::TestCase
  def setup
    @gateway = MxMerchantGateway.new(fixtures(:mx_merchant))

    @amount = 900
    @credit_card = credit_card('4100000000000001')
    @declined_card = credit_card('4100000000000001')
    @invalid_card = credit_card('1232424242424242', {verification_value: '88'})
    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
#    assert_match /^AUTH\/TKT\ .+$/, response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: "127.0.0.1",
      email: "joe@example.com"
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
#    assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  end

  def test_failed_purchase_due_to_invalid_card_number
    response = @gateway.purchase(@amount, @invalid_card, @options)
    assert_failure response
    assert_equal 'ValidationError', response.error_code
  end

  def test_failed_purchase_due_to_issuer_decline
    response = @gateway.purchase(123412, @declined_card, @options)
    assert_failure response
    assert_equal 'ValidationError', response.error_code
  end

# Not implemented, yet. -mab 2015-11-01
#   def test_successful_authorize_and_capture
#     auth = @gateway.authorize(@amount, @credit_card, @options)
#     assert_success auth
# 
#     assert capture = @gateway.capture(@amount, auth.authorization)
#     assert_success capture
#     assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
#   end
# 
# Not implemented, yet. -mab 2015-11-01
#   def test_failed_authorize
#     response = @gateway.authorize(@amount, @declined_card, @options)
#     assert_failure response
#     assert_equal 'REPLACE WITH FAILED AUTHORIZE MESSAGE', response.message
#   end
# 
# Not implemented, yet. -mab 2015-11-01
#   def test_partial_capture
#     auth = @gateway.authorize(@amount, @credit_card, @options)
#     assert_success auth
# 
#     assert capture = @gateway.capture(@amount-1, auth.authorization)
#     assert_success capture
#   end
# 
# Not implemented, yet. -mab 2015-11-01
#   def test_failed_capture
#     response = @gateway.capture(@amount, '')
#     assert_failure response
#     assert_equal 'REPLACE WITH FAILED CAPTURE MESSAGE', response.message
#   end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, @credit_card, @options)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, @credit_card, @options)
    assert_success refund
  end

# Not implemented, yet. -mab 2015-11-01
#   def test_failed_refund
#     response = @gateway.refund(@amount, '')
#     assert_failure response
#     assert_equal 'REPLACE WITH FAILED REFUND MESSAGE', response.message
#   end
#
# Not implemented, yet. -mab 2015-11-01
#   def test_successful_void
#     auth = @gateway.authorize(@amount, @credit_card, @options)
#     assert_success auth
# 
#     assert void = @gateway.void(auth.authorization)
#     assert_success void
#     assert_equal 'REPLACE WITH SUCCESSFUL VOID MESSAGE', response.message
#   end
# 
# Not implemented, yet. -mab 2015-11-01
#   def test_failed_void
#     response = @gateway.void('')
#     assert_failure response
#     assert_equal 'REPLACE WITH FAILED VOID MESSAGE', response.message
#   end
# 
# Not implemented, yet. -mab 2015-11-01
#   def test_successful_verify
#     response = @gateway.verify(@credit_card, @options)
#     assert_success response
#     assert_match %r{REPLACE WITH SUCCESS MESSAGE}, response.message
#   end
# 
# Not implemented, yet. -mab 2015-11-01
#   def test_failed_verify
#     response = @gateway.verify(@declined_card, @options)
#     assert_failure response
#     assert_match %r{REPLACE WITH FAILED PURCHASE MESSAGE}, response.message
#   end

  def test_invalid_login
    @gateway = MxMerchantGateway.new(username: "invalid", password: "no")
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'InvalidCredentials', response.error_code
    
  end

#   def test_dump_transcript
#     # This test will run a purchase transaction on your gateway
#     # and dump a transcript of the HTTP conversation so that
#     # you can use that transcript as a reference while
#     # implementing your scrubbing logic.  You can delete
#     # this helper after completing your scrub implementation.
#     dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
#   end


# Not implemented, yet. -mab 2015-11-01
#   def test_transcript_scrubbing
#     transcript = capture_transcript(@gateway) do
#       @gateway.purchase(@amount, @credit_card, @options)
#     end
#     transcript = @gateway.scrub(transcript)
# 
#     assert_scrubbed(@credit_card.number, transcript)
#     assert_scrubbed(@credit_card.verification_value, transcript)
#     assert_scrubbed(@gateway.options[:password], transcript)
#   end

end
