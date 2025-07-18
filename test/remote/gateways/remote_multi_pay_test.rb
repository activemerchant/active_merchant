require 'test_helper'

class RemoteMultiPayTest < Test::Unit::TestCase
  def setup
    @gateway = MultiPayGateway.new(fixtures(:multi_pay))

    @amount = 100
    @credit_card = credit_card('5413330089020516', month: 1, year: 2030, verification_value: '111')
    @declined_card = credit_card('4000000000000002')
    @options = {
      order_id: SecureRandom.hex(16),
      billing_address: address,
      email: 'customer@example.com'
    }
  end

  def test_successful_authorization
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'APROBADA (00)', response.message
  end

  def test_authorization_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'APROBADA (00)', response.message

    @options[:order_id] = SecureRandom.hex(16)

    capture_response = @gateway.capture(@amount, response.authorization, @options)
    assert_success capture_response
    assert_equal 'APROBADA (00)', capture_response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'APROBADA (00)', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match %r{NO HAY TAL EMISOR}i, response.message
  end

  def test_invalid_login
    error = assert_raises(ActiveMerchant::OAuthResponseError) do
      gateway = MultiPayGateway.new(
        company: '123456',
        branch: 'branch_name',
        pos: 'terminal_id',
        user: 'username',
        password: 'password'
      )
      gateway.purchase(@amount, @credit_card, @options)
    end

    assert_match(/401/, error.message)
  end

  def test_successful_purchase_with_3d_secure
    @options[:three_d_secure] = {
      data: {
        ds_transaction_id: '0039cc67-2a7a-4dde-807f-935edb6c44a5',
        authentication_value: 'AgAAAAAAAIR8CQrXSohbQAAAAAA=',
        acs_transaction_id: '98e94050-61c9-4dc9-9280-0322be501970',
        ds_reference_number: 'd6c703c2-a42e-4e9c-a2aa-d33d852b',
        server_transaction_id: '45ec66e7-536e-43dd-827c-24fa3f8cfed1',
        server_reference_number: '3DS_LOA_SER_PPFU_020100_00008',
        acs_reference_number: '3DS_LOA_ACS_PPFU_020100_00009'
      }
    }
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'APROBADA (00)', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
  end
end
