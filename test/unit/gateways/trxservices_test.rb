require 'test_helper'

class TrxservicesTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = TrxservicesGateway.new(fixtures(:trxservices))
    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      :number             => '4111111111111111',
      :month              => 12,
      :year               => 2019,
      :first_name         => 'Robert',
      :last_name          => 'Frost'
    )
    @credit_card.verification_value = 346
    @amount = 14.12
    @address = { address1: '811 Hickory St', zip: 68108, city: 'Omaha', state: 'NE', country: 'USA' }
    @email = 'test@example.com'
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, address: @address, email: @email)
    assert_success response

    assert_equal 'Approved', response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, address: @address, email: @email)
    assert_failure response
    assert_equal "Duplicate found", response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, address: @address, email: @email)
    assert_success response
    assert_equal "Approved", response.message
  end
#
  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, address: @address, email: @email)
    assert_failure response
    assert_equal "Duplicate found", response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, guid: '5DWXJEG8FL9LM0K')
    assert_success response
    assert_equal "Approved", response.message
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, guid: '5DWXJEG8FL9LM0K')
    assert_failure response
    assert_equal "Validation Error (db business logic failure)", response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, guid: '5DWHEN1VFK75JKW')
    assert_success response
    assert_equal "Approved", response.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, guid: '5DWHEN1VFK75JKW')
    assert_failure response
    assert_equal "Validation Error (db business logic failure)", response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void(@amount, guid: '5DWHEN1VFK75JKW')
    assert_success response
    assert_equal "Approved", response.message
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void(@amount, guid: '5DWHEN1VFK75JKW')
    assert_failure response
    assert_equal "Validation Error (db business logic failure)", response.message
  end

  private

  def successful_purchase_response
    "<Message><Response>BN/BDnCmjy1V0FX8BOn+eUWvdY719xv2lPV1x5i4K6ZUzaMANMJ25BGROCoVZQMnIxwCnqWBz4M7M4eo5d580NJRXkt2GW5YEEXawA66nzhKdB0t7GkBygbEp1Y2qznjFXa7LLAaxUGVzwAGV6GbQviT7sTHxH5wxX0+KFFbmHQBk+AT/kIgD1rLySB66O9/OffDLrVZb+Eyk6a4K0Cd0gSgpKrAjBZvJYnT8c1rz4doJYOWlx9YGWLyucy34bkxP8ZYNVTcQmeqZyRfnpkBZcJ22QYjZqSWNPT5M+OPlG+tXHLrB2adcaGp8XsBz+CxnAEZ9mOF8uqN0xweeXaCEdi7R9JgJzlnoJCQc0WHIwUFgeVLdrQpNgB3UuozI7BMz3pPwn+0S5hUExSIzWf4q2a4z5N4EfUH+qVjpoE4/NF4F8TXhZIwskBoXopX0nLO</Response><Authentication><Client>207</Client><Source>1</Source></Authentication></Message>"
  end

  def failed_purchase_response
    "<Message><Response>BN/BDnCmjy1V0FX8BOn+eQZc8fUNiGVgkRxw14HimC25WHewdwcyLKT9LReKbknMWl/wwS3J8OXFgrclMK/XdvV38ZtG7+H90bNffUW+zQOwyfc5jX4yOICOoUqkdZL2HLRZX3HdPZXSSWEBAqDQgaQvDQODwLBHVCcqqZTqgWVy4ciiItsn21XTxpnmq81GJapm4wYw7JIM3aCz+1FZcvj18kW3ZCRgYFyS/QjWfGJJv7x50g3rpBrT/2h1jVPsK4VVMLiTgmSmYYo2MkX3X6reS23s4UuxT3zCiVMFAUhoNO8uVQgg2AVAbKR2zCVeCrFA8oYWD9HLfevuJAEagTBs1xRFWbxHVvc2oY4JmG10kuu9VOYrurb6CgXBx6K6P2d7mmxv+5O73dfDGkZrPOqIkow/qF/pBvBwZFFfBRz5E9W55fEGlFUZahtT2u9LI9C8kjbj2cPKJtLG//4M2LRLyiX528VJpVcD33j2kZBk9Nd0s732CN9QTh2f91ZgC//THrdcx295miGBuR61xLN6poiILm/pmgbss08HLqk=</Response><Authentication><Client>207</Client><Source>1</Source></Authentication></Message>"
  end

  def successful_authorize_response
    "<Message><Response>BN/BDnCmjy1V0FX8BOn+eaHUe+l0wSsOGcDkgDoS7O+RimxZM+qga/UxufFzvmau47MUJ/qooUdX8mpgmQCeexkRIhAXBE+94Tn7kvFYWH/DeewEqJuPaVTHyvSyDwybLNv+BmStreKx3Xk//TDt2af1JmxgFJptuu9Q6AlDRtJij6+68zzvB5eydiE33yLJRdNmof0husrrrAZ4NtP/cF2fIzuAKDlg6dheW1I/JQ6QBCN/9s12ZZHqnHmcyjyDEktPA16wjoOHeZbGJZfiiT3Q5B2UVxoP/RAL8k29ocXTW2xtT5d28H0BJDSAVfTlFrgzgaIhp5qf8h4GyPNnOWT0Nwtja70CjA4xY9bbNxNaqA5+mwiJaLOMr2zFskf89qj8ET2NnSPyXaHd5Wb0HIV5Wb/dzWNHMkAzcbYu3BSrsXpMYnZ1wimYfNY/KiU9</Response><Authentication><Client>207</Client><Source>1</Source></Authentication></Message>"
  end

  def failed_authorize_response
    "<Message><Response>BN/BDnCmjy1V0FX8BOn+eW1ZKfOWINxnPLvMKHYTjw5nZkPR+Yxub0MC3sR7ChvWSXAbo7T1KStn2HiG3W0aVUcd4mFnS6On1eDquJRN0e2TDUQ5uIn1WPerK8qJm5g3RUAvyimKv+JSXKq0T68Tq7ZUjKbWjCN9Pf2iRck9Wn2qhl2zILJp5HP/WoyHWqrmASbhW5DpgKmOTuMOlhuaLaW/HZAgrTSlZBtbgLf61UFjJAstYdLAlkIPI68E6+Y0TJtNgNv3WYGxx6mjd/3ruG+/tg1/bssYHKZeRZ9qwI5y5i2eq1+twv67ZERlEWfcZyr4rLaBS6GgYNEsZVOgII2T4yZw7itRJ0REyeuyatH59fzg74/pheA7Fty7mrtaNZ5C3jQF60T38Ue5KFRuuZOx2A9+aIuszFcipOysBjTjqqObywKlZaRkkg4LxPy5M2wGdkyQYUxEYzPbhMVJ2B95RgbZKuEJ4SdGhB2Z/JCQ31X5jdGsuXnQEWQlTqEgeC6n3HCVYGXwwF4E6KXgjxEz8/zJYsUcPlN54YQ6F40=</Response><Authentication><Client>207</Client><Source>1</Source></Authentication></Message>"
  end

  def successful_capture_response
    "<Message><Response>BN/BDnCmjy1V0FX8BOn+ecenZH0G5urhHVxfI8vg1+SLRw3gkOMumljWHp7EyeaYZKH40+sTCvaP4vNJbNnapX4WD2eLtc0IqovfJuVJGlkfXLRIfZ+Myai+wzZFiD+ZA8noGSP+fc7UFIyXn5vkdpBXn/xe5gJljVo2BrUDNTWIB5PDQ5PJ2fK+bekQtlgLmrahYQLo/3yYn1jlB9AM7PcyEmdV2IeLR5ryh34lrpaI8Z1PRx6WDrmlWiA88ddDbKtiTBlnyTEKykWrLIDQZQ==</Response><Authentication><Client>207</Client><Source>1</Source></Authentication></Message>"
  end

  def failed_capture_response
    "<Message><Response>BN/BDnCmjy1V0FX8BOn+eQe0AGa2ZpYEzRQyxT972HSB0SYL+KsZtvabgCpXXfCyUz/yN7TutUQkXdfY+2xVjBNEIUBhYOinV9dsYjNSqOE7Sa+9v5XMYNDCnbNZwHamxOR9E6K4U60km2Sb/Cud073ryk37Lz4KojY6giHC2ClGY+SFoHodvCAPvL3KdjVjJP4J284zaZNjkaoJ1oW8NUZC74GKv+iHLYm05CnP82y171M/vdxG6cWPN/NOC6ciATed+TMsxEX5gjeETXtKokvpMw4esDm8NRQW1MVzw2aXyWHgEhltClaU2f3Re2pG4vEnsj1qSWjkXbzBSg3pWDx+NtKIPd2OzkhaLZawqUk=</Response><Authentication><Client>207</Client><Source>1</Source></Authentication></Message>"
  end

  def successful_refund_response
    "<Message><Response>BN/BDnCmjy1V0FX8BOn+eRaAG0+haMjOJIXG/nayrWIldUcfsVDBJHOTaQdyM9mJUsNLaTMTZstUQQc7W2F4y4V4lQ2IqK/fRXiMt+rmJfa5w9KJ9j6fu1pet7blTCeVWipiZGeQeVUw9+AlPfrmqwZsSumG8HiQ50zHUPtZWQhsRqoMxfX7FMDTK5iWmPzTu+66EC79PCoM2cqT71vmH6/+e9Z9Bfzwwv+Q5IbbpHf37rT5IOt0i0vXJ+MR/smW3y5lre/r1j3xKBN/LhKeNA==</Response><Authentication><Client>207</Client><Source>1</Source></Authentication></Message>"
  end

  def failed_refund_response
    "<Message><Response>BN/BDnCmjy1V0FX8BOn+eRrfO6wtCpXGfqcmO7udBtO5z4ULp8NJWUw/Tea2KKmfpXgIfPQg10QpFnaSO+kEyro4DEAkwXogzdJawLV4gE9jEMdotPAxZUkZ1eQ+cbHrvWucYJfvj9W7aJT9+yU6J5ebFEVnTzfWmKLO4nJiK4h078uTQlWRJT6zPKS/JZ5uX9hlJYfv73SiqIbQVXwqiyNqJc9iwDizxont+3q3v97+n1g1z7UieOMsRe2Xdn+KV5qa/h2saojoppbvVv+gHfUD2AbUqgrWrkn/VK/Ml5jqeJsaaj/SnH0KoyfS16IbVYu6wAu12UMbGwMvgeUrxZYcsyxvvKp01wvruI6yeU6OobU0oDQ9s8g4Ib9bGjjV</Response><Authentication><Client>207</Client><Source>1</Source></Authentication></Message>"
  end

  def successful_void_response
    "<Message><Response>BN/BDnCmjy1V0FX8BOn+edO7TN4dJDgTZxWp0fBeDG19PnRRZa+WBAyYsdikc2dD0N6s0KdgimpxlguxskgjYt7b1MY2hTpBcrbPWrOMRsMQMYO3jbEmn7smonZAovBVFdX56uLcWlThS0+rbL+AdaXLjnHKURlCpyUTqseTnOnZyd8bWv6myumkrQwayyJEo+65Mqw+rlazY3WFVOvmwYKhkpBzDUmJ6M7w2ZHfoNnziVKt+FTXQEs8J4g7GPBIvKc5Rcx31Mfg4mH70tFwew==</Response><Authentication><Client>207</Client><Source>1</Source></Authentication></Message>"
  end

  def failed_void_response
    "<Message><Response>BN/BDnCmjy1V0FX8BOn+eVWvjIIDeKvqGVKMFzp4hJ/sbZGqSH5JaKxUy9GMc95hNeFso0/BgAhy/oneSgMHxcWx90PBDe4Ml4dHbtflUEdIiezPhGKnOVRegDQK710bFrLRxJMolzSUTJm9LBR0Z58l+usrVAp94XQzVvx6tmGxB6nVbLuLo33ycqUtTooNBC1hEBo7hlR27SdsKijfT3ajchgQfLSZS3gRFBFelgTQlzRcnF9VDimPrg47mGmlC2WN4IRG9bKM0oTaFmwIufZ6Aw2z+vr7N+L6xVkk3g+MOpVT0ZwGovztDtw+tuSVNy/RwKRlZIsC9P2AfHD+d1Ix19q3B0v5WlbYwaQS8UpxWTIgWlH6+rYRsAdTSkFW</Response><Authentication><Client>207</Client><Source>1</Source></Authentication></Message>"
  end

end
