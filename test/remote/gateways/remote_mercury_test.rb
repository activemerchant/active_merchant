require 'test_helper'

class RemoteMercuryTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test

    @gateway = MercuryGateway.new(fixtures(:mercury))

    @amount = 100

    @mc_track2 = "5499990123456781=13051015432198712345"
    @disc_track2 = "6011000997235373=11085025432198712345"
    @visa_track2 = "4003000123456781=13055025432198712345"
    @amex_track2 = "373953244361001=11085025432198712345"

    @mc = CreditCard.new(
      :brand => "master",
      :number => "5499990123456781",
      :verification_value => "123",
      :month => 8,
      :year => 2013,
      :first_name => 'Fred',
      :last_name => 'Brooks')
    @discover = CreditCard.new(
        :brand => "discover",
        :number => "6011000997235373",
        :verification_value => "123",
        :month => 8,
        :year => 2013,
        :first_name => 'Fred',
        :last_name => 'Brooks')
    @amex = CreditCard.new(
      :brand => "american_express",
      :number => "373953244361001",
      :verification_value => "123",
      :month => 8,
      :year => 2013,
      :first_name => 'Fred',
      :last_name => 'Brooks')
    @visa = CreditCard.new(
      :brand => "visa",
      :number => "4003000123456781",
      :verification_value => "123",
      :month => 8,
      :year => 2013,
      :first_name => 'Fred',
      :last_name => 'Brooks')


    @declined_card = credit_card('4000300011112220')

    @invoice = 100

    @options_with_billing = {
      :merchant => '999',
      :description => "Open Dining Mercury Integration v1.0",
      :billing_address => {
        :address1 => '4 Corporate Square',
        :zip => '30329'
      }
    }
    @options = {
      :merchant => 'test',
      :description => "Open Dining Mercury Integration v1.0"
    }
    @full_options = {
      :order_id => '1',
      :ip => '123.123.123.123',
      :merchant => "Open Dining",
      :description => "Open Dining Integration",
      :customer => "Tim",
      :tax => "5",
      :billing_address => {
        :address1 => '4 Corporate Square',
        :zip => '30329'
      }
    }

    @visa_partial_card = CreditCard.new(:number => "4005550000000480", :month => 12, :year => 2015)
    @visa_partial_track2 = "4005550000000480=15125025432198712345"

    @disc_partial_card = CreditCard.new(:number => "6011900212345677", :month => 12, :year => 2015)
    @disc_partial_track2 = "6011900212345677=15125025432198712345"
  end

  def test_visa_pre_auth_and_capture_swipe
    invoice = 500
    assert visa_response = @gateway.authorize(100, @visa_track2,
      @options.merge(:order_id => invoice, :invoice => invoice))
    assert_success visa_response
    assert_equal '1.00', visa_response.params['authorize']

    assert visa_capture = @gateway.capture(100, visa_response.authorization,
      CreditCard.new(:number => visa_response.params["acct_no"],
        :month => visa_response.params["exp_date"][0..1],
        :year => visa_response.params["exp_date"][-2..-1]),
      @options.merge(:order_id => visa_response.params["ref_no"], :invoice => invoice,
      :acq_ref_data => visa_response.params['acq_ref_data']))
    assert_success visa_capture
    assert_equal '1.00', visa_capture.params['authorize']
  end

  def test_mastercard_pre_auth_and_capture_with_void_sale_swipe
    invoice = 501
    assert mc_response = @gateway.authorize(200, @mc_track2,
      @options.merge(:order_id => invoice, :invoice => invoice))
    assert_success mc_response
    assert_equal '2.00', mc_response.params['authorize']

    assert mc_capture = @gateway.capture(200, mc_response.authorization,
      CreditCard.new(:number => mc_response.params["acct_no"],
        :month => mc_response.params["exp_date"][0..1],
        :year => mc_response.params["exp_date"][-2..-1]),
      @options.merge(:order_id => mc_response.params['ref_no'], :invoice => invoice,
        :acq_ref_data => mc_response.params['acq_ref_data']))
    assert_success mc_capture
    assert_equal '2.00', mc_capture.params['authorize']

    assert void_response = @gateway.void(200, mc_capture.authorization,
      CreditCard.new(:number => mc_capture.params["acct_no"],
        :month => mc_capture.params["exp_date"][0..1],
        :year => mc_capture.params["exp_date"][-2..-1]),
      @options.merge(:order_id => mc_capture.params['ref_no'], :invoice => mc_capture.params['invoice_no']))

    assert_success void_response
    assert_equal '2.00', void_response.params['purchase']
    assert_equal 'VoidSale', void_response.params['tran_code']
  end

  def test_visa_pre_auth_and_capture_manual
    invoice = 502
    assert response = @gateway.authorize(300, @visa, @options.merge(:order_id => invoice, :invoice => invoice))
    assert_success response
    assert_equal '3.00', response.params['authorize']

    assert capture = @gateway.capture(300, response.authorization, @visa,
      @options.merge(:order_id => response.params['ref_no'], :invoice => response.params['invoice_no'],
      :acq_ref_data => response.params['acq_ref_data']))
    assert_success capture
    assert_equal '3.00', capture.params['authorize']
  end

  def test_mastercard_pre_auth_and_capture_manual
    invoice = 503
    assert mc_response = @gateway.authorize(400, @mc, @options_with_billing.merge(:order_id => invoice, :invoice => invoice))
    assert_success mc_response
    assert_equal '4.00', mc_response.params['authorize']

    assert mc_capture = @gateway.capture(400, mc_response.authorization, @mc,
      @options.merge(:order_id => mc_response.params['ref_no'], :invoice => mc_response.params['invoice_no'],
      :acq_ref_data => mc_response.params['acq_ref_data'], :tip => 150))
    assert_success mc_capture
    assert_equal '5.50', mc_capture.params['authorize']
  end

  def test_visa_voice_auth_manual
    invoice = 504
    assert response = @gateway.voice_authorize(650, "123456", @visa, @options_with_billing.merge(:order_id => invoice, :invoice => invoice))

    assert_success response
    assert_equal 'Success', response.message
  end

  def test_amex_pre_auth_and_disconnect_manual
    invoice = 505
    assert response = @gateway.authorize(125, @amex, @options_with_billing.merge(:order_id => invoice, :invoice => invoice))
    assert_success response
    assert_equal '1.25', response.params['authorize']

    # this is a disconnect test, so we save the response for the next test
    assert capture = @gateway.capture(125, response.authorization, @amex,
      @options.merge(:order_id => response.params['ref_no'], :invoice => response.params['invoice_no'],
      :acq_ref_data => response.params['acq_ref_data']))
    assert_success capture
    assert_equal '1.25', capture.params['authorize']

    assert capture2 = @gateway.capture(125, response.authorization, @amex,
      @options.merge(:order_id => response.params['ref_no'], :invoice => response.params['invoice_no'],
      :acq_ref_data => response.params['acq_ref_data']))
    assert_success capture2
    assert_equal '1.25', capture2.params['authorize']

    assert capture3 = @gateway.capture(125, response.authorization, @amex,
      @options.merge(:order_id => response.params['ref_no'], :invoice => response.params['invoice_no'],
      :acq_ref_data => response.params['acq_ref_data']))
    assert_success capture3
    assert_equal '1.25', capture3.params['authorize']
  end

  def test_discover_pre_auth_and_capture_and_adjust_manual
    invoice = 506
    assert response = @gateway.authorize(225, @discover, @options_with_billing.merge(:order_id => invoice, :invoice => invoice))
    assert_success response
    assert_equal '2.25', response.params['authorize']

    assert capture = @gateway.capture(225, response.authorization, @discover,
      @options.merge(:order_id => response.params['ref_no'], :invoice => response.params['invoice_no'],
      :acq_ref_data => response.params['acq_ref_data']))
    assert_success capture
    assert_equal '2.25', capture.params['authorize']

    assert adjustment = @gateway.adjust(225, response.authorization, @discover,
      @options.merge(:order_id => capture.params['ref_no'], :invoice => capture.params['invoice_no'],
      :acq_ref_data => capture.params['acq_ref_data'], :tip => 175))
    assert_success adjustment
    assert_equal '4.00', adjustment.params['authorize']
  end

  def test_visa_return_void_return_swipe
    invoice = 507
    assert response = @gateway.credit(375, @visa_track2, @options.merge(:order_id => invoice, :invoice => invoice))
    assert_success response
    assert_equal '3.75', response.params['purchase']

    assert void_response = @gateway.void(375, response.authorization,
      CreditCard.new(:number => response.params["acct_no"],
        :month => response.params["exp_date"][0..1],
        :year => response.params["exp_date"][-2..-1]),
      @options.merge(:order_id => response.params['ref_no'], :invoice => response.params['invoice_no'],
        :void => 'VoidReturn'))

    assert_success void_response
    assert_equal '3.75', void_response.params['purchase']
    assert_equal 'VoidReturn', void_response.params['tran_code']
  end

  def test_mastercard_return_manual
    invoice = 508
    assert response = @gateway.credit(425, @mc, @options.merge(:order_id => invoice, :invoice => invoice))
    assert_success response
    assert_equal '4.25', response.params['purchase']
  end

  def test_visa_pre_auth_failure_swipe
    invoice = 509
    assert response = @gateway.authorize(1100, @visa_track2, @options.merge(:order_id => invoice, :invoice => invoice))
    assert_failure response
    assert_equal "DECLINE", response.message
  end

  def test_mastercard_pre_auth_date_failure_manual
    invoice = 510
    @mc.month = 13
    @mc.year = 2001
    assert response = @gateway.authorize(575, @mc, @options_with_billing.merge(:order_id => invoice, :invoice => invoice))
    assert_failure response
    assert_equal "INVLD EXP DATE", response.message
  end

  def test_visa_sale_swipe
    invoice = 511
    assert response = @gateway.purchase(50, @visa_track2, @options.merge(:order_id => invoice, :invoice => invoice))

    assert_success response
    assert_equal "0.50", response.params["purchase"]
  end

  def test_mastercard_sale_manual
    invoice = 512
    assert response = @gateway.purchase(75, @mc_track2, @options.merge(:order_id => invoice, :invoice => invoice))

    assert_success response
    assert_equal "0.75", response.params["purchase"]
  end

  def test_visa_preauth_avs_cvv_manual
    invoice = 513
    assert response = @gateway.authorize(333, @visa, @options_with_billing.merge(:order_id => invoice, :invoice => invoice))

    assert_success response
    assert_equal response.avs_result, {"code" => "Y", "postal_match" => "Y", "street_match" => "Y",
      "message" => "Street address and 5-digit postal code match."}
  end

  def test_mastercard_bad_preauth_avs_cvv_manual
    invoice = 513
    @mc.month = 8
    @mc.year = 2013
    @mc.verification_value = 321
    @options_with_billing[:billing_address] = {:address => "wrong address", :zip => "12345"}

    assert response = @gateway.authorize(444, @mc, @options_with_billing.merge(:order_id => invoice, :invoice => invoice))

    assert_success response
    assert_equal response.avs_result, {"code" => "N", "postal_match" => "N", "street_match" => "N",
      "message" => "Street address and postal code do not match."}

  end

  def test_batch_summary_and_close
    assert response = @gateway.batch_summary

    assert_success response
    pars = response.params
    assert close = @gateway.batch_close(:batch_no => pars["batch_no"],
      :batch_item_count =>pars["batch_item_count"],
      :net_batch_total => pars["net_batch_total"],
      :credit_purchase_count => pars["credit_purchase_count"],
      :credit_purchase_amount => pars["credit_purchase_amount"],
      :credit_return_count => pars["credit_return_count"],
      :credit_return_amount => pars["credit_return_amount"],
      :debit_purchase_count => pars["debit_purchase_count"],
      :debit_purchase_amount => pars["debit_purchase_amount"],
      :debit_return_count => pars["debit_return_count"],
      :debit_return_amount => pars["debit_return_amount"])

    assert_equal "OK TEST", close.params["text_response"]
  end

  def test_preauth_partial_auth_visa
    @invoice = 156
    assert response = @gateway.authorize(2354, @visa_partial_track2, @options.merge(:invoice => @invoice, :order_id => @invoice))

    assert_success response

    assert capture = @gateway.capture(2000,
      response.authorization,
      CreditCard.new(:number => response.params["acct_no"],
        :month => response.params["exp_date"][0..1],
        :year => response.params["exp_date"][-2..-1]),
      @options.merge(:order_id => response.params["ref_no"], :invoice => @invoice,
      :acq_ref_data => response.params['acq_ref_data']))
    assert_success capture

    assert reverse = @gateway.void(2000,
      response.authorization,
      @visa_partial_card,
      @options.merge(:order_id => capture.params["ref_no"], :invoice => @invoice,
      :acq_ref_data => capture.params['acq_ref_data'], :process_data => capture.params["process_data"]))
    assert_success reverse
  end

  def test_preauth_partial_discover
    @invoice = 157
    assert response = @gateway.authorize(2307, @disc_partial_track2, @options.merge(:invoice => @invoice, :order_id => @invoice))
    assert_success response

    assert capture = @gateway.capture(2000,
      response.authorization,
      CreditCard.new(:number => response.params["acct_no"],
        :month => response.params["exp_date"][0..1],
        :year => response.params["exp_date"][-2..-1]),
      @options.merge(:order_id => response.params["ref_no"], :invoice => @invoice,
      :acq_ref_data => response.params['acq_ref_data']))
    assert_success capture

    assert reverse = @gateway.void(2000,
      response.authorization,
      @disc_partial_card,
      @options.merge(:order_id => capture.params["ref_no"], :invoice => @invoice,
      :acq_ref_data => capture.params['acq_ref_data'], :process_data => capture.params["process_data"]))
    assert_success reverse
  end
end
