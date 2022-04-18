require 'test_helper'

class RemoteShift4Test < Test::Unit::TestCase
  def setup
    @gateway = Shift4Gateway.new(fixtures(:shift4))

    @amount = 5
    @invoice = '3333333309'
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')
    @declined_card.number = '400030001111220'
    @options = {
      order_id: '1',
      company_name: 'Spreedly',
      billing_address: address,
      description: 'Store Purchase',
      "tax": 1,
      "tip": '',
      "total": 5.00,
      clerk_id: 24,
      invoice: rand(4).to_s,
      security_code: {
        indicator: '1',
        value: '4444'
      }
    }
    @refund_options = @options.except(:invoice).merge({
      invoice: @invoice,
      notes: 'Transaction notes are added here',
      billing_address: address,
      stored_credential: {
        indicator: '01',
        usage_indicator: '01',
        scheduled_indicator: '01',
        transaction_id: 'yxx'
      },
      token: {
        serial_number: '',
        value: '1111g66gw3ryke06'
      }
    })
    @capture_params = @options.except(:invoice).merge({
      transaction: {
        invoice: @invoice
      },
      card: {}
    })
    @purchase_params = {
      company_name: 'Spreedly',
      tax: 0,
      total: 219,
      clerk_id: 16,
      transaction: {
        invoice: '4666309473',
        notes: 'Test payment'
      },
      card: {
        expiration_date: '0825',
        present: 'N',
        indicator: '1',
        value: '3333'
      }
    }
    @token = '8042677003331111'
    @void_options = { company_name: 'Spreedly', invoice: @invoice }
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal response.message, 'Transaction successful'
    assert_equal @options[:total], response_result(response)['amount']['total']
  end

  def test_successful_capture
    authorize_res = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize_res
    response = @gateway.capture(@amount, authorize_res.authorization, @capture_params)

    assert_success response
    assert_equal response.message, 'Transaction successful'
    assert_equal @options[:total], response_result(response)['amount']['total']
    assert response_result(response)['transaction']['invoice'].present?
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @purchase_params)
    assert_success response
    assert_equal @options[:total], response_result(response)['amount']['total']
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.authorize(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)
    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed("0#{@credit_card.month}#{@credit_card.year.to_s[2..4]}", transcript)
    assert_scrubbed(@options[:billing_address][:name], transcript)
  end

  def test_failed_purchase
    auth_token = '8038483489222221'
    @purchase_params[:card][:expiration_date] = '085'
    response = @gateway.purchase(@amount, auth_token, @purchase_params)

    assert_failure response
    assert response_result(response)['error']['longText'].include?('No GTV PAN returned from host')
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)

    assert_failure response
    assert response_result(response)['error']['longText'].include?('Card  for Merchant Id')
  end

  def test_failed_capture
    auth_token = '8038483489222221'
    @capture_params[:card][:expiration_date] = '085'
    response = @gateway.capture(@amount, auth_token, @capture_params)

    assert_failure response
    assert response_result(response)['error']['longText'].include?('No GTV PAN returned from host')
  end

  def test_failed_refund
    response = @gateway.refund(nil, @credit_card, @refund_options.except(:access_token))

    assert_failure response
    assert response_result(response)['error']['longText'].include?('Secondary amounts cannot exceed the total amount')
  end

  def test_successful_refund
    res = @gateway.purchase(@amount, @credit_card, @purchase_params)
    assert_success res
    response = @gateway.refund(@amount, res.authorization, @refund_options)

    assert_success response
    assert_equal @refund_options[:total], response_result(response)['amount']['total']
    assert_equal @refund_options[:invoice], response_result(response)['transaction']['invoice']
  end

  def test_successful_void
    authorize_res = @gateway.authorize(@amount, @credit_card, @options)
    assert response = @gateway.void(authorize_res.authorization, @void_options)

    assert_success response
    assert_equal @refund_options[:total], response_result(response)['amount']['total']
    assert_equal @void_options[:invoice], response_result(response)['transaction']['invoice']
  end

  def test_failed_void
    response = @gateway.void('', @void_options.except(:invoice))
    assert_failure response
    assert response_result(response)['error']['longText'].include?('Invoice Not Found')
    assert_equal response_result(response)['error']['primaryCode'], 9815
  end

  private

  def response_result(response)
    response.params['result'][0]
  end
end
