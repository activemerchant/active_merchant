require 'test_helper'

class RemoteCyberSourceTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = CyberSourceGateway.new({nexus: 'NC'}.merge(fixtures(:cyber_source)))

    @credit_card = credit_card('4111111111111111', verification_value: '321')
    @declined_card = credit_card('801111111111111')
    @pinless_debit_card = credit_card('4002269999999999')
    @three_ds_unenrolled_card = credit_card('4000000000000051',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :visa
    )
    @three_ds_enrolled_card = credit_card('4000000000000002',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :visa
    )
    @three_ds_invalid_card = credit_card('4000000000000010',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :visa
    )

    @amount = 100

    @options = {
      :order_id => generate_unique_id,
      :line_items => [
        {
          :declared_value => 100,
          :quantity => 2,
          :code => 'default',
          :description => 'Giant Walrus',
          :sku => 'WA323232323232323'
        },
        {
          :declared_value => 100,
          :quantity => 2,
          :description => 'Marble Snowcone',
          :sku => 'FAKE1232132113123'
        }
      ],
      :currency => 'USD',
      :ignore_avs => 'true',
      :ignore_cvv => 'true'
    }

    @subscription_options = {
      :order_id => generate_unique_id,
      :credit_card => @credit_card,
      :subscription => {
        :frequency => 'weekly',
        :start_date => Date.today.next_week,
        :occurrences => 4,
        :auto_renew => true,
        :amount => 100
      }
    }
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_network_tokenization_transcript_scrubbing
    credit_card = network_tokenization_credit_card('4111111111111111',
      :brand              => 'visa',
      :eci                => '05',
      :payment_cryptogram => 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    )

    transcript = capture_transcript(@gateway) do
      @gateway.authorize(@amount, credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(credit_card.number, transcript)
    assert_scrubbed(credit_card.payment_cryptogram, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_unsuccessful_authorization
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert response.test?
    assert_equal 'Invalid account number', response.message
    assert_equal false,  response.success?
  end

  def test_authorize_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert void = @gateway.void(auth.authorization, @options)
    assert_equal 'Successful transaction', void.message
    assert_success void
    assert void.test?
  end

  def test_capture_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
    assert void = @gateway.void(capture.authorization, @options)
    assert_equal 'Successful transaction', void.message
    assert_success void
    assert void.test?
  end

  def test_successful_tax_calculation
    assert response = @gateway.calculate_tax(@credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert response.params['totalTaxAmount']
    assert_not_equal '0', response.params['totalTaxAmount']
    assert_success response
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_purchase_sans_options
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'Successful transaction', response.message
    assert_success response
  end

  def test_successful_purchase_with_billing_address_override
    @options[:billing_address] = address
    @options[:email] = 'override@example.com'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
  end

  def test_successful_purchase_with_long_country_name
    @options[:billing_address] = address(country: 'united states', state: 'NC')
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
  end

  def test_successful_purchase_without_decision_manager
    @options[:decision_manager_enabled] = 'false'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_purchase_with_decision_manager_profile
    @options[:decision_manager_enabled] = 'true'
    @options[:decision_manager_profile] = 'Regular'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_pinless_debit_card_puchase
    assert response = @gateway.purchase(@amount, @pinless_debit_card, @options.merge(:pinless_debit_card => true))
    assert_equal 'Successful transaction', response.message
    assert_success response
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_equal 'Invalid account number', response.message
    assert_failure response
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Successful transaction', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_successful_authorization_and_failed_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Successful transaction', auth.message

    assert capture = @gateway.capture(@amount + 10, auth.authorization, @options)
    assert_failure capture
    assert_equal 'The requested amount exceeds the originally authorized amount',  capture.message
  end

  def test_failed_capture_bad_auth_info
    assert @gateway.authorize(@amount, @credit_card, @options)
    assert capture = @gateway.capture(@amount, 'a;b;c', @options)
    assert_failure capture
  end

  def test_invalid_login
    gateway = CyberSourceGateway.new( :login => 'asdf', :password => 'qwer' )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "wsse:FailedCheck: \nSecurity Data : UsernameToken authentication failed.\n", response.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
    assert response = @gateway.refund(@amount, response.authorization)
    assert_equal 'Successful transaction', response.message
    assert_success response
  end

  def test_successful_validate_pinless_debit_card
    assert response = @gateway.validate_pinless_debit_card(@pinless_debit_card, @options)
    assert response.test?
    assert_equal 'Y', response.params['status']
    assert_equal true,  response.success?
  end

  def test_network_tokenization_authorize_and_capture
    credit_card = network_tokenization_credit_card('4111111111111111',
      :brand              => 'visa',
      :eci                => '05',
      :payment_cryptogram => 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    )

    assert auth = @gateway.authorize(@amount, credit_card, @options)
    assert_success auth
    assert_equal 'Successful transaction', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize_with_mdd_fields
    (1..20).each { |e| @options["mdd_field_#{e}".to_sym] = "value #{e}" }
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_purchase_with_mdd_fields
    (1..20).each { |e| @options["mdd_field_#{e}".to_sym] = "value #{e}" }
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_authorize_with_nonfractional_currency
    assert response = @gateway.authorize(100, @credit_card, @options.merge(:currency => 'JPY'))
    assert_equal '1', response.params['amount']
    assert_success response
  end

  def test_successful_subscription_authorization
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?

    assert response = @gateway.authorize(@amount, response.authorization, :order_id => generate_unique_id)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_successful_subscription_purchase
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?

    assert response = @gateway.purchase(@amount, response.authorization, :order_id => generate_unique_id)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_subscription_credit
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?

    assert response = @gateway.credit(@amount, response.authorization, :order_id => generate_unique_id)

    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_create_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_create_subscription_with_setup_fee
    assert response = @gateway.store(@credit_card, @subscription_options.merge(:setup_fee => 100))
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_create_subscription_with_monthly_options
    response = @gateway.store(@credit_card, @subscription_options.merge(:setup_fee => 99.0, :subscription => {:amount => 49.0, :automatic_renew => false, frequency: 'monthly'}))
    assert_equal 'Successful transaction', response.message
    response = @gateway.retrieve(response.authorization, order_id: @subscription_options[:order_id])
    assert_equal '0.49', response.params['recurringAmount']
    assert_equal 'monthly', response.params['frequency']
  end

  def test_successful_update_subscription_creditcard
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?

    assert response = @gateway.update(response.authorization, @credit_card, {:order_id => generate_unique_id, :setup_fee => 100})
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_update_subscription_billing_address
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?

    assert response = @gateway.update(response.authorization, nil,
      {:order_id => generate_unique_id, :setup_fee => 100, billing_address: address, email: 'someguy1232@fakeemail.net'})
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_delete_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?

    assert response = @gateway.unstore(response.authorization, :order_id => generate_unique_id)
    assert response.success?
    assert response.test?
  end

  def test_successful_retrieve_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?

    assert response = @gateway.retrieve(response.authorization, :order_id => generate_unique_id)
    assert response.success?
    assert response.test?
  end

  def test_3ds_enroll_request_via_purchase
    assert response = @gateway.purchase(1202, @three_ds_enrolled_card, @options.merge(payer_auth_enroll_service: true))
    assert_equal '475', response.params['reasonCode']
    assert !response.params['acsURL'].blank?
    assert !response.params['paReq'].blank?
    assert !response.params['xid'].blank?
    assert !response.success?
  end

  def test_3ds_enroll_request_via_authorize
    assert response = @gateway.authorize(1202, @three_ds_enrolled_card, @options.merge(payer_auth_enroll_service: true))
    assert_equal '475', response.params['reasonCode']
    assert !response.params['acsURL'].blank?
    assert !response.params['paReq'].blank?
    assert !response.params['xid'].blank?
    assert !response.success?
  end

  def test_successful_3ds_requests_with_unenrolled_card
    assert response = @gateway.purchase(1202, @three_ds_unenrolled_card, @options.merge(payer_auth_enroll_service: true))
    assert response.success?

    assert response = @gateway.authorize(1202, @three_ds_unenrolled_card, @options.merge(payer_auth_enroll_service: true))
    assert response.success?
  end

  def test_successful_3ds_validate_purchase_request
    assert response = @gateway.purchase(1202, @three_ds_enrolled_card, @options.merge(payer_auth_validate_service: true, pares: pares))
    assert_equal '100', response.params['reasonCode']
    assert_equal '0', response.params['authenticationResult']
    assert response.success?
  end

  def test_failed_3ds_validate_purchase_request
    assert response = @gateway.purchase(1202, @three_ds_invalid_card, @options.merge(payer_auth_validate_service: true, pares: pares))
    assert_equal '476', response.params['reasonCode']
    assert !response.success?
  end

  def test_successful_3ds_validate_authorize_request
    assert response = @gateway.authorize(1202, @three_ds_enrolled_card, @options.merge(payer_auth_validate_service: true, pares: pares))
    assert_equal '100', response.params['reasonCode']
    assert_equal '0', response.params['authenticationResult']
    assert response.success?
  end

  def test_failed_3ds_validate_authorize_request
    assert response = @gateway.authorize(1202, @three_ds_invalid_card, @options.merge(payer_auth_validate_service: true, pares: pares))
    assert_equal '476', response.params['reasonCode']
    assert !response.success?
  end

  def pares
    <<-PARES
eNqdmFuTqkgSgN+N8D90zD46M4B3J+yOKO6goNyFN25yEUHkUsiv31K7T/ec6dg9u75YlWRlZVVmflWw1uNrGNJa6DfX8G0thVXlRuFLErz+tgm67sRlbJr3ky4G9LWn8N/e1nughtVD4dFawFAodT8OqbBx4NLdj/o8y3JqKlavSLsNr1VS5G/En/if4zX20UUTXf3Yzeu3teuXpCC/TeerMTFfY+/d9Tm8CvRbEB7dJqvX2LO7xj7H7Zt7q0JOd0nwpo3VacjVvMc4pZcXfcjFpMqLc6UHr2vsrrEO3Dp8G+P4Ap+PZy/E9C+c+AtfrrGHfH25mwPnokG2CRxfY18Fa7Q71zD3b2/LKXr0o7cOu0uRh0gDre1He419+nZx8zf87z+kepeu9cPbuk7OX31a3X0iFmvsIV9XtVs31Zu9xt5ba99t2zcAAAksNjsr4N5MVctyGIaN2H6E1vpQWYd+8obPkFPo/zEKZFFxTer4fHf174I1dncFe4Tzba0lUY4mu4Yv3TnLURDjur78hWEQwj/h5M/iGmHIYRzDVxhSCKok+tdvz1FhIOTH4n8aRrl5kSe+myW9W6PEkMI6LoKXH759Z0ZX75YITGWoP5CpP3ximv9xl+ATYoZsYt8b/bKyX5nlZ2evlftHFbvEfYKfDL2t1fAY3jMifDFU4fW3f/1KZdBJFFb1/+PKhxtfLXzYM92sCd8qN5U5lrrNDZOFzkiecUIszvyCVJjXj3FPzTX2w/f3hT2j+GW3noobXm8xXJ3KK2aZztNbVdsLWbbOASZgzSY45eYqFNiK5ReRNLKbzvZSIDJj+zqBzIEkIx1L9ZTabYeDJa/MV51fF9A0dxDvxzf5CiPmttuVVBLHxmZSNp53lnBcJzh+IS3YpejKebycHjQlvMggwkvHdZjhYBHf8M1R4ikKjHxMGxlCfuCv+IqmxjTRk9GMnO2ynnXsWMvZSYdlk+Vmvpz1pVns4v05ugRWIGZNMhxUGLzoqs+VDe14Jtzli63TT06WBvpJg2+2UVLie+5mgGDlEVjip+7EmZhCvRdndtQHmKm0vaUDejhYTRgglbR5qysx6I1gf+vTyWJ3ahaXNOWBUrXRYnwasbKlbi3XsJLNuA3g6+uXrHqPzCa8PSNxmKElubX7bGmNl4Z+LbuIEJT8SrnXIMnd7IUOz8XLI4DX3192xucDQGlI8NmnijOiqR/+/rJ9lRCvCqSv6a+7OCl+f6FeDW2N/TzPY2IqvNbJEdUVwqUkCLTVo32vtAhAgQSRQAFNgLRii5vCEeLWl4HCsKQCoJMyWwmcOEAYDBlLlGlKHa2DLRnJ5nCAhkoksypca9nxKfDvUhIUEmvIsX9WL96ZrZTxqvYs82aPjQi1bz7NaBIJHhYpCEXplJ2GA8ea4a7lXCRVgUxk06ai0DSoDecg4wIvE3ZC0ooOQhbinUQzNyn1OzkFM5kWXSS7PWVKNxx8SCV+2VE9EJ8+2TrITF1ScEjBh3WBgere5bJWUpb3ld9lPAMd+e6JNxGQJS4F9vuKdObLigRGbj2LyPyznEmqAZmnxS0DO9o+iCfXmsUeRZIKIXW8Djy0Tw8rks4yX62omWctI2Oc5d7ZvKGokEIKZDI6lfEp4VYQJ+9RAGBHAWUJ7s+HAyraoB4DSmYSEIl4LuOMDMYCIZJ71pj7U99OwbapLHXFMLI66s7eKosO9qmWU56LwmJCul2tccin+XTKE4tV7EatfZaSNCQFH9bYXMNCetuoK2kl0SN6An3f3xmIMwGIT8KlZZS5pV/wpTIz8FzIF9fhIK6EhVLuzEDAg4MI+sybxjVzA/TGuEmsEHDZbZFBtjKxdKfgilSRZDLRoGjQmpWlzUEZGeJ+7CK6jCNPPgQe2ZInYsxH5YEWZoId7i5G2RJNax3USyCJo1OXS/jNLKdCtZiMSaCR4jKPaXvXqjl/6Et+OMBDRoth7MfSnLa3o7ItpxyV8CZcmjrVbJtyWykIypti158qotvx1VkJTm48GzeYBAUaKIAsJhUcDkL9mUO8KjEgBUCiIEdZFKcBjhsxAkpL5cjGxN7nzMYgZElgguweT/ugZg5F0s5BfGT2cGCPWdzRQfCwpkzRoa8YasSpRuIhBMUdRVxBGyn1FouIkytA/p5XKp4iAEO2AMZRSKQkIPDhgLC0ZSKTIV5IsXXC55ue+a566chmgKyLBwZfHlr7igWzo4Dn4m63WjXm3kMV3G7GNc3KJz9Ur5pt1AxBnafhdFf03bi2pnQlT8pZhWNWN7Mu+6RtWe/I6AbUz1wcFd6puR7FdrSYDwcYP5lcIsJ0ZNh7zOxcqcSFOjoUhaui645OzZ5qHGeazOnrqlxJ1+2eSJtTNOo7bBrgyvIanQyHuh9xP/PqO4BROI0Alp6/AOzbLYAh/asAo/t78d0L1ZdQ/mVerrZ+yoQSCZ+wiqCpjNmbw2WNbXW0NyZqFNzU0Uh0dHgTEUqqABnwhAENTjfNUu9WLs751LE60N8xINGsmvkTJTLOqzag/g624UDS72hjelmXP9GmKz9kEmf/R7DR4Ak2ZEmdQv7pz4YmzU84fQHYHWZ+DjomBcrTYiVRuig6KJ1R5Z5dhD5kiRQeewAg3Jqc2SOv+8ASIgVnYOQsf9558pl8OIIWJ4KCQ4u+QWKmIqgK7g5MOZ+0XJ4jemPuucVRUPf5rma5LL6U7RxuXQ4ax+NodrIvC4k53wRDanhGdkGrnhJRq2/UajccHM67ebQItvRyk3PEnFrl1y5dFuT0PEFYMqbn0dG2dlx+js/7Yt7HZFuSVXvsV5OYiTYHec4EG7kxo+GgKfvamoPtDhry3CPLjaJN7okBAJeGPTl7z5+AgQolAQC3wBZtwRGA7U2ViJFJcmnxxgo+jjHdwGGkjs0G5UYccOYJ7XDmP7IgS+9QkEj8YY2OFIsk1WUi3MTJQTed7U3A2YUW3Vh3OND14irp4PiAhSYxHA2siFSZKN1jhOVFme2MOa7LKcst80SEKId+OjqM+9GBjoxIIZfNxsBWkyVmbmYUa4iJghm7gzu+8jeiAxMvJwhiR80zcl4FSr2Q01jx442ebHWlimZHrNQymRgOto7dtFMgbPTdxmG4ayKWQJ+Lp3K0OcQ1rU2jtLyw+XKXOqWoLo7ulVFHgTebYaLWXho+Sr1OPy7AcHCGCar/njbEqWk2ib1Z6iWb3cbm1eTZ6PVXIdCmCAJJ+AEBEYh0tx8xmanGGwngHKWVnCZ4E/qRkgaQ+OgfpYOS+5vi+XoroMHnreA/3XIQBP7LPefzlvPj1oBuOd3zlsOKrYegcC+p4YCPfRmFv5NSZiLpNpR1cLPusvQhw3/IUnIqKRWknr5yDBRNo2dkCVSPmdGNAUBGH8cXr2f29z15gBBCTrfuBb66/SokhoP/gglTIqUPSEjvkNC88QpHo0kEguNHRIaDj5igJAWIBjKgKTJRNmSkUNPwevRaVWGow9Vezev9QtlZJaWDcZpjs3SywiKsxD0p8RVKHQ6u49ExWZz6zY28KaVz4ntbnC0nGDi0G9GFeM2id5cJkwbRKezMS2ZrYcnsZzuDlqaRqx0XJS9F5h6VycYt8nF7TfnOCimzY5NpNyWLIBPzY4ZhNZdu8FKm+3pxwqZyqLHWzSsT5f2mQACop8+THcXu42wXhB5bmeepaHFBHFcOzM7lZZr4DPOPs/073eHgQ5sGD22dBAZE4SSx/vtijxSQsEuSy0gWSqEshkxiw9xVEJhqg78mbmrU3nxGzJe1fLxwDDO59rxHzgrpzPiHrvK8WlDJpo33y3MdhU7GZ81W6fFSHfnjYpbBcDjo4CLNjoAvSxRlLaU2W76plphc5At/tEhKra8VXiLN0FuM59Ddt5zgHZitL1vFyttHamkZ44sToxvD5ubwK/BtsWOfr03Yj1epz5esx7ekx8eu+/ePrx/B/g0UAjN8
    PARES
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = CyberSourceGateway.new(login: 'an_unknown_login', password: 'unknown_password')
    assert !gateway.verify_credentials
  end

end
