# encoding: utf-8

require 'test_helper'

class PayboxDirectTest < Test::Unit::TestCase
  def setup
    @gateway = PayboxDirectGateway.new(
                 :login => 'l',
                 :password => 'p'
               )

    @credit_card = credit_card('1111222233334444',
                      :brand => 'visa'
                   )
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal response.params['numappel'].to_s + response.params['numtrans'], response.authorization
    assert_equal 'XXXXXX', response.params['autorisation']
    assert_equal "The transaction was approved", response.message
    assert response.test?
  end

  def test_purchase_with_default_currency
    @gateway.expects(:ssl_post).with do |_, body|
      body.include?('DEVISE=978')
    end.returns(purchase_response)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_purchase_with_set_currency
    @options.update(currency: 'GBP')

    @gateway.expects(:ssl_post).with do |_, body|
      body.include?('DEVISE=826')
    end.returns(purchase_response)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_deprecated_credit
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/NUMAPPEL=transid/), anything).returns("")
    @gateway.expects(:parse).returns({})
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE) do
      @gateway.credit(@amount, "transid", @options)
    end
  end

  def test_refund
    @gateway.expects(:ssl_post).with(anything) do |_, body|
      body.include?('NUMAPPEL=transid')
      body.include?('MONTANT=0000000100&DEVISE=97')
    end.returns("")

    @gateway.expects(:parse).returns({})
    @gateway.refund(@amount, "transid", @options)
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Demande trait?e avec succ?s ✔漢", response.message
    assert response.test?
  end

  def test_keep_the_card_code_not_considered_fraudulent
    @gateway.expects(:ssl_post).returns(purchase_response("00104"))

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert !response.fraud_review?
  end

  def test_do_not_honour_code_not_considered_fraudulent
    @gateway.expects(:ssl_post).returns(purchase_response("00105"))

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert !response.fraud_review?
  end

  def test_card_absent_from_file_code_not_considered_fraudulent
    @gateway.expects(:ssl_post).returns(purchase_response("00156"))

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert !response.fraud_review?
  end

  def test_version
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/VERSION=00103/)).returns(purchase_response)
    @gateway.purchase(@amount, @credit_card, @options)
  end

  private

  # Place raw successful response from gateway here
  def purchase_response(code="00000")
    "NUMTRANS=0720248861&NUMAPPEL=0713790302&NUMQUESTION=0000790217&SITE=1999888&RANG=99&AUTORISATION=XXXXXX&CODEREPONSE=#{code}&COMMENTAIRE=Demande trait?e avec succ?s ✔漢"
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    'NUMTRANS=0000000000&NUMAPPEL=0000000000&NUMQUESTION=0000000000&SITE=1999888&RANG=99&AUTORISATION=&CODEREPONSE=00014&COMMENTAIRE=Demande trait?e avec succ?s ✔漢'
  end
end
