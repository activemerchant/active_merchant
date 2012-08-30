require 'test_helper'

class RemoteMercuryPrepaidTest < Test::Unit::TestCase
  

  def setup
    Base.gateway_mode = :test
    
    @gateway = MercuryPrepaidGateway.new(fixtures(:mercury))
    
    # this card works - to test new ones increase the number
    @prepaid_card = CreditCard.new(:number => "6050110000006083336")
    
    @blank_test_card = CreditCard.new(:number => "6050110000006083330-1")
    @blank_test_track2 = "6050110000006083330=250110112"
    
    @blank_test2_card = CreditCard.new(:number => "6050110000006083332-1")
    @blank_test2_track2 = "6050110000006083332=250110110"
    
    @blank_test3_card = CreditCard.new(:number => "6050110000006083333-1")
    @blank_test3_track2 = "6050110000006083333=250110119"
    
    @options = { 
      :merchant => '999',
      :description => "Open Dining Mercury Integration v1.0"
    }
    @full_options = {
      :order_id => '1',
      :ip => '123.123.123.123',
      :merchant => "Open Dining",
      :description => "Open Dining Mercury Integration",
      :customer => "Tim",
      :tax => "5",
      :billing_address => {
        :address1 => '4 Corporate Square',
        :zip => '30329'
      }
    }
    
  end
=begin
  # larget test - it all deals with the same card from issue onwards
  def test_issue
    invoice = 100
    assert response = @gateway.issue(500, @blank_test2_track2, 
      @options.merge(:invoice => invoice, :order_id => invoice))
    assert_success response

  end

  def test_swiped_and_manual_sale
    invoice = 501
    assert swiped = @gateway.sale(100, @blank_test2_track2, @options.merge(:invoice => invoice, :order_id => invoice))
    assert_success swiped
    invoice = 502
    assert manual = @gateway.sale(200, @blank_test2_card, @options.merge(:invoice => invoice, :order_id => invoice))
    assert_success manual
    #invoice = 103
    assert manual2 = @gateway.sale(200, @blank_test2_card, @options.merge(:invoice => invoice, :order_id => invoice))
    assert_failure manual2
    invoice = 504
    assert swipe2 = @gateway.sale(400, @blank_test2_track2, @options.merge(:invoice => invoice, :order_id => invoice))
    assert_failure swipe2
  end

  def test_reload
    invoice = 105
    assert reload = @gateway.reload(400, @blank_test2_track2, @options.merge(:invoice => invoice, :order_id => invoice))
    assert_success reload
    invoice = 106
    assert reload2 = @gateway.reload(350, @blank_test2_card, @options.merge(:invoice => invoice, :order_id => invoice))
    assert_success reload2
  end

  def test_balance
    invoice = 107
    assert balance = @gateway.balance(@blank_test2_track2, @options.merge(:invoice => invoice, :order_id => invoice))
    assert_success balance
  end

  def test_sale_and_void_sale
    invoice = 108
    assert sale = @gateway.sale(150, @blank_test2_track2, @options.merge(:invoice => invoice, :order_id => invoice))
    assert_success sale
    
    assert void = @gateway.void(150, sale.authorization, @blank_test2_track2, 
      @options.merge(:void => 'VoidSale', :order_id => sale.params['ref_no'], 
      :invoice => sale.params['invoice_no']))
    assert_success void
    
  end


  def test_reload_void_reload
    invoice = 109
    assert reload = @gateway.reload(250, @blank_test2_card, @options.merge(:invoice => invoice, :order_id => invoice))
    assert_success reload
    
    assert void = @gateway.void(250, reload.authorization, @blank_test2_card, 
      @options.merge(:void => 'VoidReload', :order_id => reload.params['ref_no'], 
      :invoice => reload.params['invoice_no']))

    assert_success void 
  end

  def test_issue_and_void_manual
    invoice = 45
    assert response = @gateway.issue(1000, @blank_test3_card, @options.merge(:invoice => invoice, :order_id => invoice))
    assert_success response
    
    assert void_response = @gateway.void(1000, response.authorization, @blank_test3_card,
      @options.merge(:order_id => response.params['ref_no'], :invoice => response.params['invoice_no']))
    assert_success response
  end

  def test_balance_for_non_issued_card
    invoice = 46
    assert balance = @gateway.balance(@blank_test3_card, @options.merge(:invoice => invoice, :order_id => invoice))
    assert_failure balance
  end
=end
  def test_issue_and_purchase
    invoice = 47
    assert response = @gateway.issue(300, @blank_test3_track2, @options.merge(:invoice => invoice, :order_id => invoice))
    assert_success response
    
    invoice = 48
    assert purchase = @gateway.purchase(700, @blank_test3_track2, @options.merge(:invoice => invoice, :order_id => invoice))
    assert_success purchase
  end
=begin
  def test_issue_and_cvv_sale
    invoice = 113
    assert response = @gateway.issue(100, @blank_test3_track2, 
      @options.merge(:invoice => invoice, :order_id => invoice))
    assert_success response
    
    invoice = 114
    assert sale = @gateway.sale(100, @blank_test3_track2, 
      @options.merge(:invoice => invoice, :order_id => invoice, :cvv_data => "19"))
    assert_success sale
  end
  
=begin


  def test_purchase_balance_reload    
    assert purchase = @gateway.purchase(1500, @prepaid_card, @options)
    assert_success purchase
    
    assert balance = @gateway.balance(@prepaid_card, @options)
    assert_success balance
    
    assert reload = @gateway.reload(1500, @prepaid_card, @options)
    assert_success reload
  end
  
  def test_purchase_void    
    assert purchase = @gateway.purchase(1500, @prepaid_card, @options)
    assert_success purchase
    
    assert void = @gateway.void(1500, purchase.authorization, @prepaid_card, 
      @options.merge(:void => 'VoidSale', :order_id => purchase.params['ref_no'], 
      :invoice => purchase.params['invoice_no']))
    assert_success void
    assert_equal "VoidSale", void.params["tran_code"]
    
  end
  
  def test_purchase_return_cashout
    #assert purchase = @gateway.purchase(1500, @prepaid_card, @options)
    #assert_success purchase
    #assert_equal @balance - 15.00, purchase.params["balance"]
    
  end
  
  def test_issue_and_void_issue
    #assert response = @gateway.issue(@amount, @prepaid_card, @options)

    #assert void_response = @gateway.void(@amount, response.authorization, @prepaid_card,
    #  @options.merge(:order_id => response.params['ref_no'], :invoice => response.params['invoice_no']))
      
  end
  
  def test_issue_and_purchase
    #assert response = @gateway.issue(@amount, @prepaid_card5, @options)
    
    #assert purchase_response = @gateway.purchase(@amount + 300, @prepaid_card5, @options)
    
  end
  
  def test_issue_and_return
    #assert response = @gateway.issue(@amount, @prepaid_card6, @options)
    
    #assert purchase_response = @gateway.purchase(@amount + 300, @prepaid_card6, @options)
    
    #assert credit_response = @gateway.credit(@amount + 300, @prepaid_card6, @options)
    
  end
=end
end
