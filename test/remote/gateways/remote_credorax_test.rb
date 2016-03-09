require 'test_helper'

class RemoteCredoraxTest < Test::Unit::TestCase
  def setup
    @gateway = CredoraxGateway.new(fixtures(:credorax))

    @amount = 100
    @credit_card = credit_card('5223450000000007', verification_value: "090", month: "12", year: "2025")
    @declined_card = credit_card('4000300011112220')
    @options = {
      currency: "EUR",
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_invalid_login
      gateway = CredoraxGateway.new(merchant_id: "", cipher_key: "")
      response = gateway.purchase(@amount, @credit_card, @options)
      assert_failure response
    end

    def test_successful_purchase
      response = @gateway.purchase(@amount, @credit_card, @options)
      assert_success response
      assert_equal "Succeeded", response.message
    end

    def test_failed_purchase
      response = @gateway.purchase(@amount, @declined_card, @options)
      assert_failure response
      assert_equal "Transaction has been declined.", response.message
    end

    def test_successful_authorize_and_capture
      response = @gateway.authorize(@amount, @credit_card, @options)
      assert_success response
      assert_equal "Succeeded", response.message
      assert response.authorization

      capture = @gateway.capture(@amount, response.authorization)
      assert_success capture
      assert_equal "Succeeded", capture.message
    end

    def test_failed_authorize
      response = @gateway.authorize(@amount, @declined_card, @options)
      assert_failure response
      assert_equal "Transaction has been declined.", response.message
      assert_equal "05", response.params["Z2"]
    end

    def test_failed_capture
      response = @gateway.capture(@amount, "")
      assert_failure response
      assert_equal "2. At least one of input parameters is malformed.: Parameter [g4] cannot be empty.", response.message
      assert_equal "-9", response.params["Z2"]
    end

    def test_successful_purchase_and_void
      response = @gateway.purchase(@amount, @credit_card, @options)
      assert_success response

      void = @gateway.void(response.authorization)
      assert_success void
      assert_equal "Succeeded", void.message
    end

    def test_successful_authorize_and_void
      response = @gateway.authorize(@amount, @credit_card, @options)
      assert_success response

      void = @gateway.void(response.authorization)
      assert_success void
      assert_equal "Succeeded", void.message
    end

    def test_successful_capture_and_void
      response = @gateway.authorize(@amount, @credit_card, @options)
      assert_success response
      assert_equal "Succeeded", response.message
      assert response.authorization

      capture = @gateway.capture(@amount, response.authorization)
      assert_success capture
      assert_equal "Succeeded", capture.message

      void = @gateway.void(capture.authorization)
      assert_success void
      assert_equal "Succeeded", void.message
    end

    def test_failed_void
      response = @gateway.void("")
      assert_failure response
      assert_equal "2. At least one of input parameters is malformed.: Parameter [g4] cannot be empty.", response.message
      assert_equal "-9", response.params["Z2"]
    end

    def test_successful_refund
      response = @gateway.purchase(@amount, @credit_card, @options)
      assert_success response

      refund = @gateway.refund(@amount, response.authorization)
      assert_success refund
      assert_equal "Succeeded", refund.message
    end

    def test_successful_refund_and_void
      response = @gateway.purchase(@amount, @credit_card, @options)
      assert_success response

      refund = @gateway.refund(@amount, response.authorization)
      assert_success refund
      assert_equal "Succeeded", refund.message

      void = @gateway.void(refund.authorization)
      assert_success void
      assert_equal "Succeeded", void.message
    end

    def test_failed_refund
      response = @gateway.refund(nil, "")
      assert_failure response
      assert_equal "2. At least one of input parameters is malformed.: Parameter [g4] cannot be empty.", response.message
      assert_equal "-9", response.params["Z2"]
    end

    def test_successful_credit
      response = @gateway.credit(@amount, @credit_card, @options)
      assert_success response
      assert_equal "Succeeded", response.message
    end

    def test_failed_credit
      response = @gateway.credit(@amount, @declined_card, @options)
      assert_failure response
      assert_equal "Transaction has been declined.", response.message
    end

    def test_successful_verify
      response = @gateway.verify(@credit_card, @options)
      assert_success response
      assert_equal "Succeeded", response.message
    end

    def test_failed_verify
      response = @gateway.verify(@declined_card, @options)
      assert_failure response
      assert_equal "Transaction has been declined.", response.message
      assert_equal "05", response.params["Z2"]
    end

    def test_transcript_scrubbing
      transcript = capture_transcript(@gateway) do
        @gateway.purchase(@amount, @credit_card, @options)
      end
      clean_transcript = @gateway.scrub(transcript)

      assert_scrubbed(@credit_card.number, clean_transcript)
      assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
    end
end
