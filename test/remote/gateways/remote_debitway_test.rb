require 'test_helper'

class RemoteDebitwayTest < Test::Unit::TestCase
  def setup
    @gateway = DebitwayGateway.new(fixtures(:debitway))

    @amount = 1000

    @credit_card = credit_card('4444777711119999',
        {
            :verification_value => 123,
            :month              => 12,
            :year               => 2018
        }
    )

    @declined_card = credit_card('4000300011112220')

    @options = {
        :order_id   => generate_unique_id,
        :billing_address => {
            :name => 'xiaobo zzz',
            :phone => '555-555-5555',
            :address1 => '4444 Levesque St.',
            :address2 => 'Apt B',
            :city => 'Montreal',
            :state => 'QC',
            :country => 'CA',
            :zip => 'H2C1X8'
        },
        :first_name     => 'Jon',
        :last_name      => 'Doe',
        :email          => 'testemail@debitway.com',
        :phone          => '55544433344',
        :ip             => '126.44.22.11',
        :description    => 'Store Purchase',
        :custom         => 'Additional Description',
        :return_url     => 'http://www.sample.com/return/'
    }

  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end


  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'FAILURE', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture

    assert_equal 'SUCCESS', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'FAILURE', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'FAILURE', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund

    assert_equal 'SUCCESS', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)

    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'FAILURE', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void

    assert_equal 'SUCCESS', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'FAILURE', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{SUCCESS}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{FAILURE}, response.message
  end

  def test_invalid_login
    gateway = DebitwayGateway.new(identifier: '', vericode: '', website_unique_id: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response

    assert_match %r{FAILURE}, response.message
  end

  def test_dump_transcript
    # This test will run a purchase transaction on your gateway
    # and dump a transcript of the HTTP conversation so that
    # you can use that transcript as a reference while
    # implementing your scrubbing logic.  You can delete
    # this helper after completing your scrub implementation.
    # dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:identifier], transcript)
    assert_scrubbed(@gateway.options[:vericode], transcript)
    assert_scrubbed(@gateway.options[:website_unique_id], transcript)
  end

end
