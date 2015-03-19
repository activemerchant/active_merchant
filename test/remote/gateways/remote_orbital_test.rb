require "test_helper.rb"

class RemoteOrbitalGatewayTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    @gateway = ActiveMerchant::Billing::OrbitalGateway.new(fixtures(:orbital))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :order_id => generate_unique_id,
      :address => address,
    }

    @cards = {
      :visa => "4788250000028291",
      :mc => "5454545454545454",
      :amex => "371449635398431",
      :ds => "6011000995500000",
      :diners => "36438999960016",
      :jcb => "3566002020140006"}

    @test_suite = [
      {:card => :visa, :AVSzip => 11111, :CVD =>	111,  :amount => 3000},
      {:card => :visa, :AVSzip => 33333, :CVD =>	nil,  :amount => 3801},
      {:card => :mc,	 :AVSzip => 44444, :CVD =>	nil,  :amount => 4100},
      {:card => :mc,	 :AVSzip => 88888, :CVD =>	666,  :amount => 1102},
      {:card => :amex, :AVSzip => 55555, :CVD =>	nil,  :amount => 105500},
      {:card => :amex, :AVSzip => 66666, :CVD =>	2222, :amount => 7500},
      {:card => :ds,	 :AVSzip => 77777, :CVD =>	nil,  :amount => 1000},
      {:card => :ds, 	 :AVSzip => 88888, :CVD =>	444,  :amount => 6303},
      {:card => :jcb,  :AVSzip => 33333, :CVD =>	nil,  :amount => 2900}]
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  # Amounts of x.01 will fail
  def test_unsuccessful_purchase
    assert response = @gateway.purchase(101, @declined_card, @options)
    assert_failure response
    assert_equal 'AUTH DECLINED                   12001', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options.merge(:order_id => '2'))
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization, :order_id => '2')
    assert_success capture
  end

  def test_authorize_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options.merge(:order_id => '2'))
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization
    assert void = @gateway.void(auth.authorization, :order_id => '2')
    assert_success void
  end

  def test_refund
    amount = @amount
    assert response = @gateway.purchase(amount, @credit_card, @options)
    assert_success response
    assert response.authorization
    assert refund = @gateway.refund(amount, response.authorization, @options)
    assert_success refund
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Bad data error', response.message
  end

  # == Certification Tests

  # ==== Section A
  def test_auth_only_transactions
    for suite in @test_suite do
      amount = suite[:amount]
      card = credit_card(@cards[suite[:card]], :verification_value => suite[:CVD])
      @options[:address].merge!(:zip => suite[:AVSzip])
      assert response = @gateway.authorize(amount, card, @options)
      assert_kind_of Response, response

      # Makes it easier to fill in cert sheet if you print these to the command line
      # puts "Auth/Resp Code => " + (response.params["auth_code"] || response.params["resp_code"])
      # puts "AVS Resp => " + response.params["avs_resp_code"]
      # puts "CVD Resp => " + response.params["cvv2_resp_code"]
      # puts "TxRefNum => " + response.params["tx_ref_num"]
      # puts
    end
  end

  # ==== Section B
  def test_auth_capture_transactions
    for suite in @test_suite do
      amount = suite[:amount]
      card = credit_card(@cards[suite[:card]], :verification_value => suite[:CVD])
      options = @options; options[:address].merge!(:zip => suite[:AVSzip])
      assert response = @gateway.purchase(amount, card, options)
      assert_kind_of Response, response

      # Makes it easier to fill in cert sheet if you print these to the command line
      # puts "Auth/Resp Code => " + (response.params["auth_code"] || response.params["resp_code"])
      # puts "AVS Resp => " + response.params["avs_resp_code"]
      # puts "CVD Resp => " + response.params["cvv2_resp_code"]
      # puts "TxRefNum => " + response.params["tx_ref_num"]
      # puts
    end
  end

  # ==== Section C
  def test_mark_for_capture_transactions
    [[:visa, 3000],[:mc, 4100],[:amex, 105500],[:ds, 1000],[:jcb, 2900]].each do |suite|
      amount = suite[1]
      card = credit_card(@cards[suite[0]])
      assert auth_response = @gateway.authorize(amount, card, @options)
      assert capt_response = @gateway.capture(amount, auth_response.authorization)
      assert_kind_of Response, capt_response

      # Makes it easier to fill in cert sheet if you print these to the command line
      # puts "Auth/Resp Code => " + (auth_response.params["auth_code"] || auth_response.params["resp_code"])
      # puts "TxRefNum => " + capt_response.params["tx_ref_num"]
      # puts
    end
  end

  # ==== Section D
  def test_refund_transactions
    [[:visa, 1200],[:mc, 1100],[:amex, 105500],[:ds, 1000],[:jcb, 2900]].each do |suite|
      amount = suite[1]
      card = credit_card(@cards[suite[0]])
      assert purchase_response = @gateway.purchase(amount, card, @options)
      assert refund_response = @gateway.refund(amount, purchase_response.authorization, @options)
      assert_kind_of Response, refund_response

      # Makes it easier to fill in cert sheet if you print these to the command line
      # puts "Auth/Resp Code => " + (purchase_response.params["auth_code"] || purchase_response.params["resp_code"])
      # puts "TxRefNum => " + credit_response.params["tx_ref_num"]
      # puts
    end
  end

  # ==== Section F
  def test_void_transactions
    [3000, 105500, 2900].each do |amount|
      assert auth_response = @gateway.authorize(amount, @credit_card, @options)
      assert void_response = @gateway.void(auth_response.authorization, @options.merge(:transaction_index => 1))
      assert_kind_of Response, void_response

      # Makes it easier to fill in cert sheet if you print these to the command line
      # puts "TxRefNum => " + void_response.params["tx_ref_num"]
      # puts
    end
  end
end
