require 'test_helper'

class MitTest < Test::Unit::TestCase
  def setup
    @credentials = {
      commerce_id: '147',
      user: 'IVCA33721',
      api_key: 'IGECPJ0QOJJCEHUI',
      key_session: 'CB0DC4887DD1D5CEA205E66EE934E430'
    }
    @gateway = MitGateway.new(@credentials)

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      number: '4000000000000002',
      verification_value: '183',
      month: '01',
      year: '2024',
      first_name: 'Pedro',
      last_name: 'Flores Valdes'
    )

    @amount = 100

    @options = {
      order_id: '7111',
      transaction_id: '7111',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    auth_response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth_response
    assert_equal 'approved', auth_response.message

    @gateway.expects(:ssl_post).returns(successful_capture_response)
    response = @gateway.capture(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_capture_response)
    response = @gateway.capture(@amount, @credit_card, @options)

    assert_not_equal 'approved', response.message
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_not_equal 'approved', response.message
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    response = @gateway.capture(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)
    response = @gateway.capture(@amount, @credit_card, @options)

    assert_not_equal 'approved', response.message
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    response = @gateway.refund(@amount, 'testauthorization', @options)
    assert_success response

    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)
    response = @gateway.refund(@amount, 'authorizationtest', @options)
    assert_failure response
    assert_not_equal 'approved', response.message
  end

  private

  def successful_purchase_response
    %(
      2Nvuvo/fotnYnFVFHpNVPAW+U9oJVZ0eiB6jFFPixkAJi9rciTa1YKd2qPl+YybJHQaLgdITH3L+3M1N3xYObd03vZnKdTin3fXFE6B+0jcrjhMuYq1h8TP7tgfYheFVHQY6Kur/N606pCG9NAwQZ2WbpZ3Vf6byfVo7euVCRF8B95zx9ZyAbsohxrXEQpWHqd09z6SduCG2CTQG+ZfXveoJfAroOLpiRoF6KqOsprnxXP6ikhE454PAvAz4WROY51AGtPi35egb80OF69fiHg==
    )
  end

  def failed_purchase_response
    %{
      VXlw5DmHlP8LGpDmxSsdabtCw5yycFl3Jq3QYcRKbdYWYXKZR4Rv+gEZDqJH1e9Uk9FW43CtJKu4et+x8Wskc3VTOsD1BrNrOgv8EguZ+MhUQsnWeUWwqEGZd9rO4B51qS7Pb69SJb4PWsyOB0fMUBctiduyGF5kaxA2ieoLA9eGfxmoIsfBptpax37PdsaxTTHbHNQXiRkg1c9f9nyAbBzPQFD/Xuf7OOjhbECXq5Ev1OIxT97PqxVh5RQX+KIQ6gZUFVkwWDaiQh/c7KGIgI3UtXCEFxZtxTvNP81l9p6FgZRDfAcYRZfEOLE8LcqtMpW6p6GTsW6EfnvEaZxzy89xFv+RXuYdns1suxYOPb0=
    }
  end

  def successful_authorize_response
    %(
      SQOZIaVhhKGAdneX1QpUuA7ZfKNkx1vq39s8o+yLsl2kbMznbkA32/Z5ovA3leZNMHShEqJPAh4AK3BC0qiL7xETKNFv1BozHaLtZlvaPhPKMCrNeWkAdqesNpD0SvSvT7XZRarWRjcMnwGP9zSvuHqz3kaASZt7Oagh+FCssjZvXUoic7XV7owZEkEAvYiXlTfmd6sv0WYbUknMI9igr2MSe6rNBarIAscnhGJF/yW+ng0wR1pGnvtXJqlYbaTYx7urZEPP6GDfO2BeHkkMT46graqjNnQhsPLr2/Nfe6g=
    )
  end

  def failed_authorize_response
    %{
      VXlw5DmHlP8LGpDmxSsdabtCw5yycFl3Jq3QYcRKbdYWYXKZR4Rv+gEZDqJH1e9Uk9FW43CtJKu4et+x8Wskc3VTOsD1BrNrOgv8EguZ+MhUQsnWeUWwqEGZd9rO4B51qS7Pb69SJb4PWsyOB0fMUBctiduyGF5kaxA2ieoLA9eGfxmoIsfBptpax37PdsaxTTHbHNQXiRkg1c9f9nyAbBzPQFD/Xuf7OOjhbECXq5Ev1OIxT97PqxVh5RQX+KIQ6gZUFVkwWDaiQh/c7KGIgI3UtXCEFxZtxTvNP81l9p6FgZRDfAcYRZfEOLE8LcqtMpW6p6GTsW6EfnvEaZxzy89xFv+RXuYdns1suxYOPb0=
    }
  end

  def successful_capture_response
    %(
      2Nvuvo/fotnYnFVFHpNVPAW+U9oJVZ0eiB6jFFPixkAJi9rciTa1YKd2qPl+YybJHQaLgdITH3L+3M1N3xYObd03vZnKdTin3fXFE6B+0jcrjhMuYq1h8TP7tgfYheFVHQY6Kur/N606pCG9NAwQZ2WbpZ3Vf6byfVo7euVCRF8B95zx9ZyAbsohxrXEQpWHqd09z6SduCG2CTQG+ZfXveoJfAroOLpiRoF6KqOsprnxXP6ikhE454PAvAz4WROY51AGtPi35egb80OF69fiHg==
    )
  end

  def failed_capture_response
    %{
      VXlw5DmHlP8LGpDmxSsdabtCw5yycFl3Jq3QYcRKbdYWYXKZR4Rv+gEZDqJH1e9Uk9FW43CtJKu4et+x8Wskc3VTOsD1BrNrOgv8EguZ+MhUQsnWeUWwqEGZd9rO4B51qS7Pb69SJb4PWsyOB0fMUBctiduyGF5kaxA2ieoLA9eGfxmoIsfBptpax37PdsaxTTHbHNQXiRkg1c9f9nyAbBzPQFD/Xuf7OOjhbECXq5Ev1OIxT97PqxVh5RQX+KIQ6gZUFVkwWDaiQh/c7KGIgI3UtXCEFxZtxTvNP81l9p6FgZRDfAcYRZfEOLE8LcqtMpW6p6GTsW6EfnvEaZxzy89xFv+RXuYdns1suxYOPb0=
    }
  end

  def successful_refund_response
    %{
      yn3RJK3KwXedXShm/1DaCED1QA6lpFzVGORcTfHCviFTwSUxGduuhCZEWPTaiksvCpTMwMFBrdQO/2THtJ/+GH2+1vIdV5QYFbLU4QCD5G33Le1x1WAU72e8o7arPdBYapZqhiIjz1NwEPOnir2XGV1AXNAuj8OjDj+YQ42cH+iUxWYU6ROaVUhApWqgVhAWz9pZqPTeDssj3dzO/iAM9z7mlhxYnqDlHdWpPpNFdk34jPb//+xCfg13HLdplqBaeDPVuWaRiEG/pc3ttETjYw==
    }
  end

  def failed_refund_response
    %{
      i+HTzdwnXqLEh9EPAyP54p6DyHOeKlt0lZqdbNy5paxwAAUSTciZzUGgFb8t8eXakdlZXWtlFHLBIRuiUFUyLZSB/btqldzuQPc+I8dEsz5F5yL4DdI/FFtAChYEHoumAvrth9uiBeEyGoAKL9etHOTPed2RFCcZYpsA8Gc3P1LterAeZwWX91LS0PzL6mKcsSUkkLCeT2UBJCg+N7a7ipop+U9jGsGBzKMhpZH6DyjZleBfh7j8ICbwMNClI8ixSYDQvmE5/fP7AZtL4oszdVAnlALhjL0Ld1MBLmeiTIiGkycZB0dKbrN5fAS0/mpbOm64wSF3ZAM/geKaXA6jmQ==
    }
  end

  def successful_void_response
    %{
      yn3RJK3KwXedXShm/1DaCED1QA6lpFzVGORcTfHCviFTwSUxGduuhCZEWPTaiksvCpTMwMFBrdQO/2THtJ/+GH2+1vIdV5QYFbLU4QCD5G33Le1x1WAU72e8o7arPdBYapZqhiIjz1NwEPOnir2XGV1AXNAuj8OjDj+YQ42cH+iUxWYU6ROaVUhApWqgVhAWz9pZqPTeDssj3dzO/iAM9z7mlhxYnqDlHdWpPpNFdk34jPb//+xCfg13HLdplqBaeDPVuWaRiEG/pc3ttETjYw==
    }
  end

  def failed_void_response
    %{
      i+HTzdwnXqLEh9EPAyP54p6DyHOeKlt0lZqdbNy5paxwAAUSTciZzUGgFb8t8eXakdlZXWtlFHLBIRuiUFUyLZSB/btqldzuQPc+I8dEsz5F5yL4DdI/FFtAChYEHoumAvrth9uiBeEyGoAKL9etHOTPed2RFCcZYpsA8Gc3P1LterAeZwWX91LS0PzL6mKcsSUkkLCeT2UBJCg+N7a7ipop+U9jGsGBzKMhpZH6DyjZleBfh7j8ICbwMNClI8ixSYDQvmE5/fP7AZtL4oszdVAnlALhjL0Ld1MBLmeiTIiGkycZB0dKbrN5fAS0/mpbOm64wSF3ZAM/geKaXA6jmQ==
    }
  end
end
