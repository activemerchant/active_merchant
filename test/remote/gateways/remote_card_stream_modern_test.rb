require 'test_helper'

class RemoteCardStreamModernTest < Test::Unit::TestCase
  def setup
      Base.mode = :test
      
      @gateway = CardStreamModernGateway.new(fixtures(:card_stream_modern))
      
      @amex = credit_card('374245455400001',
                :month => '12',
                :year => '2014',
                :verification_value => '4887',
                :brand => :american_express
              )

      @uk_maestro = credit_card('675940410531100173',
                      :month => '12',
                      :year => '2014',
                      :issue_number => '0',
                      :verification_value => '134',
                      :brand => :switch
                    )
      
      @solo = credit_card('676740340572345678',
                :month => '12',
                :year => '2014',
                :issue_number => '1',
                :verification_value => '773',
                :brand => :solo
              )

      @mastercard = credit_card('5301250070000191',
                      :month => '12',
                      :year => '2014',
                      :verification_value => '419',
                      :brand => :master
                    )

      @declined_card = credit_card('4000300011112220',
                        :month => '9',
                        :year => '2014'
                      )

      @mastercard_options = { 
        :billing_address => { 
          :address1 => '25 The Larches',
          :city => "Narborough",
          :state => "Leicester",
          :zip => 'LE10 2RT'
        },
        :order_id => generate_unique_id,
        :description => 'Store purchase'
      }
     
      @uk_maestro_options = {
        :billing_address => { 
          :address1 => 'The Parkway',
          :address2 => "Larches Approach",
          :city => "Hull",
          :state => "North Humberside",
          :zip => 'HU7 9OP'
        },
        :order_id => generate_unique_id,
        :description => 'Store purchase'
      }
      
      @solo_options = {
        :billing_address => {
          :address1 => '5 Zigzag Road',
          :city => 'Isleworth',
          :state => 'Middlesex',
          :zip => 'TW7 8FF'
        },
        :order_id => generate_unique_id,
        :description => 'Store purchase'
      }
    end
    
    def test_successful_mastercard_purchase
      assert response = @gateway.purchase(100, @mastercard, @mastercard_options)
      assert_equal 'APPROVED', response.message
      assert_success response
      assert response.test?
      assert !response.authorization.blank?
    end
    
    def test_declined_mastercard_purchase
      assert response = @gateway.purchase(10000, @mastercard, @mastercard_options)
      assert_equal 'CARD DECLINED', response.message
      assert_failure response
      assert response.test?
    end
    
    def test_expired_mastercard
      @mastercard.year = 2005
      assert response = @gateway.purchase(100, @mastercard, @mastercard_options)
      assert_equal 'CARD EXPIRED', response.message
      assert_failure response
      assert response.test?
    end

    def test_successful_maestro_purchase
      assert response = @gateway.purchase(100, @uk_maestro, @uk_maestro_options)
      assert_equal 'APPROVED', response.message
      assert_success response
    end
    
    def test_successful_solo_purchase
      assert response = @gateway.purchase(100, @solo, @solo_options)
      assert_equal 'APPROVED', response.message
      assert_success response
      assert response.test?
      assert !response.authorization.blank?
    end
    
    def test_successful_amex_purchase
      assert response = @gateway.purchase(100, @amex, :order_id => generate_unique_id)
      assert_equal 'APPROVED', response.message
      assert_success response
      assert response.test?
      assert !response.authorization.blank?
    end
    
    def test_maestro_missing_start_date_and_issue_date
      @uk_maestro.issue_number = nil
      assert response = @gateway.purchase(100, @uk_maestro, @uk_maestro_options)
      assert_equal 'ISSUE NUMBER MISSING', response.message
      assert_failure response
      assert response.test?
    end
    
    def test_invalid_login
      gateway = CardStreamModernGateway.new(
        :login => '',
        :password => ''
      )
      assert response = gateway.purchase(100, @mastercard, @mastercard_options)
      assert_equal 'MERCHANT ID MISSING', response.message
      assert_failure response
    end
    
    def test_unsupported_merchant_currency
      assert response = @gateway.purchase(100, @mastercard, @mastercard_options.update(:currency => 'USD'))
      assert_equal "ERROR 1052", response.message
      assert_failure response
      assert response.test?
    end

  # def setup
  #   @gateway = CardStreamModernGateway.new(fixtures(:card_stream_modern))

  #   @amount = 100
  #   @credit_card = credit_card('4000100011112224')
  #   @declined_card = credit_card('4000300011112220')

  #   @options = {
  #     :order_id => '1',
  #     :billing_address => address,
  #     :description => 'Store Purchase'
  #   }
  # end

  # def test_successful_purchase
  #   assert response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success response
  #   assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  # end

  # def test_unsuccessful_purchase
  #   assert response = @gateway.purchase(@amount, @declined_card, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED PURCHASE MESSAGE', response.message
  # end

  # def test_authorize_and_capture
  #   amount = @amount
  #   assert auth = @gateway.authorize(amount, @credit_card, @options)
  #   assert_success auth
  #   assert_equal 'Success', auth.message
  #   assert auth.authorization
  #   assert capture = @gateway.capture(amount, auth.authorization)
  #   assert_success capture
  # end

  # def test_failed_capture
  #   assert response = @gateway.capture(@amount, '')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  # end

  # def test_invalid_login
  #   gateway = CardStreamModernGateway.new(
  #               :login => '',
  #               :password => ''
  #             )
  #   assert response = gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILURE MESSAGE', response.message
  # end
end
