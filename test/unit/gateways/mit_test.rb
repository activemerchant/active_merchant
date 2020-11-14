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

  def test_transcript_scrubbing
    assert @gateway.supports_scrubbing?
    assert_equal post_scrubbed, @gateway.scrub(pre_scrubbed)
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

  def pre_scrubbed
    <<-PRE_SCRUBBED
    starting SSL for wpy.mitec.com.mx:443...
    SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
    <- "POST /ModuloUtilWS/activeCDP.htm HTTP/1.1\r\nContent-Type: application/json\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: wpy.mitec.com.mx\r\nContent-Length: 607\r\n\r\n"
    <- "{\"payload\":\"<authorization>1aUSihtRXgd+1nycRfVWgv0JDZsGLsrpsNkahpkx4jmnBRRAPPao+zJYqsN4xrGMIeVdJ3Y5LlQYXg5qu8O7iZmDPTqWbyKmsurCxJidr6AkFszwvRfugElyb5sAYpUcrnFSpVUgz2NGcIuMRalr0irf7q30+TzbLRHQc1Z5QTe6am3ndO8aSKKLwYYmfHcO8E/+dPiCsSP09P2heNqpMbf5IKdSwGCVS1Rtpcoijl3wXB8zgeBZ1PXHAmmkC1/CWRs/fh1qmvYFzb8YAiRy5q80Tyq09IaeSpQ1ydq3r95QBSJy6H4gz2OV/v2xdm1A63XEh2+6N6p2XDyzGWQrxKE41wmqRCxie7qY2xqdv4S8Cl8ldSMEpZY46A68hKIN6zrj6eMWxauwdi6ZkZfMDuh9Pn9x5gwwgfElLopIpR8fejB6G4hAQHtq2jhn5D4ccmAqNxkrB4w5k+zc53Rupk2u3MDp5T5sRkqvNyIN2kCE6i0DD9HlqkCjWV+bG9WcUiO4D7m5fWRE5f9OQ2XjeA==</authorization><dataID>IVCA33721</dataID>\"}"
    -> "HTTP/1.1 200 \r\n"
    -> "Strict-Transport-Security: max-age=31536000;includeSubDomains\r\n"
    -> "X-Content-Type-Options: nosniff\r\n"
    -> "X-XSS-Protection: 1; mode=block\r\n"
    -> "Content-Type: text/html;charset=ISO-8859-1\r\n"
    -> "Content-Length: 320\r\n"
    -> "Date: Mon, 06 Sep 2021 19:02:08 GMT\r\n"
    -> "Connection: close\r\n"
    -> "Server: \r\n"
    -> "Set-Cookie: UqZBpD3n=v1I4cyJQ__N2M; Expires=Mon, 06-Sep-2021 19:03:38 GMT; Path=/; Secure; HttpOnly\r\n"
    -> "\r\n"
    reading 320 bytes...
    -> "hl0spHqAAamtY47Vo+W+dZcpDyK8QRqpx/gWzIM1F3X1VFV/zNUcKCuqaSL6F4S7MqOGUMOC3BXIZYaS9TpJf6xsMYeRDyMpiv+sE0VpY2a4gULhLv1ztgGHgF3OpMjD8ucgLbd9FMA5OZjd8wlaqn46JCiYNcNIPV7hkHWNCqSWow+C+SSkWZeaa9YpNT3E6udixbog30/li1FcSI+Ti80EWBIdH3JDcQvjQbqecNb87JYad0EhgqL1o7ZEMehfZ2kW9FG6OXjGzWyhiWd2GEFKe8em4vEJxARFdXsaHe3tX0jqnF2gYOiFRclqFkbk"
    read 320 bytes
    Conn close
    opening connection to wpy.mitec.com.mx:443...
    opened
    starting SSL for wpy.mitec.com.mx:443...
    SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
    <- "POST /ModuloUtilWS/activeCDP.htm HTTP/1.1\r\nContent-Type: application/json\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: wpy.mitec.com.mx\r\nContent-Length: 359\r\n\r\n"
    <- "{\"payload\":\"<capture>Z6l24tZG2YfTOQTne8NVygr/YeuVRNya8ZUCM5NvRgOEL/Mt8PO0voNnspoiFSg+RVamC4V2BipmU3spPVBg6Dr0xMpPL7ryVB9mlM4PokUdHkZTjXJHbbr1GWdyEPMYYSH0f+M1qUDO57EyUuZv8o6QSv+a/tuOrrBwsHI8cnsv+y9qt5L9LuGRMeBYvZkkK+xw53eDqYsJGoCvpk/pljCCkGU7Q/sKsLOx0MT6dA/BLVGrGeo8ngO+W/cnOigGfIZJSPFTcrUKI/Q7AsHuP+3lG6q9VAri9UJZXm5pWOg=</capture><dataID>IVCA33721</dataID>\"}"
    -> "HTTP/1.1 200 \r\n"
    -> "Strict-Transport-Security: max-age=31536000;includeSubDomains\r\n"
    -> "X-Content-Type-Options: nosniff\r\n"
    -> "X-XSS-Protection: 1; mode=block\r\n"
    -> "Content-Type: text/html;charset=ISO-8859-1\r\n"
    -> "Content-Length: 280\r\n"
    -> "Date: Mon, 06 Sep 2021 19:02:08 GMT\r\n"
    -> "Connection: close\r\n"
    -> "Server: \r\n"
    -> "Set-Cookie: UqZBpD3n=v1JocyJQ__9tu; Expires=Mon, 06-Sep-2021 19:03:39 GMT; Path=/; Secure; HttpOnly\r\n"
    -> "\r\n"
    reading 280 bytes...
    -> "BnuAgMOx9USBreICk027VY2ZqJA7xQcRT9Ytz8WpabDnqIglj43J/I03pKLtDlFrerKIAzhW1YCroDOS7mvtA5YnWezLstoOK0LbIcYqLzj1dCFW2zLb9ssTCxJa6ZmEQdzQdl8pyY4mC0QQ0JrOrsSA9QfX1XhkdcSVnsxQV1cEooL8/6EsVFCb6yVIMhVnGL6GRCc2J+rPigHsljLWRovgRKqFIURJjNWbfqepDRPG2hCNKsabM/lE2DFtKLMs4J5iwY9HiRbrAMG6BaGNiQ=="
    read 280 bytes
    Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
    starting SSL for wpy.mitec.com.mx:443...
    SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
    <- "POST /ModuloUtilWS/activeCDP.htm HTTP/1.1\r\nContent-Type: application/json\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: wpy.mitec.com.mx\r\nContent-Length: 607\r\n\r\n"
    <- "{\"payload\":\"<authorization>{"operation":"Authorize","commerce_id":"147","user":"IVCA33721","apikey":"[FILTERED]","testMode":"YES","amount":"11.15","currency":"MXN","reference":"721","transaction_id":"721","installments":1,"card":"[FILTERED]","expmonth":9,"expyear":2025,"cvv":"[FILTERED]","name_client":"Pedro Flores Valdes","email":"nadie@mit.test","key_session":"[FILTERED]"}</authorization><dataID>IVCA33721</dataID>\"}"
    -> "HTTP/1.1 200 \r\n"
    -> "Strict-Transport-Security: max-age=31536000;includeSubDomains\r\n"
    -> "X-Content-Type-Options: nosniff\r\n"
    -> "X-XSS-Protection: 1; mode=block\r\n"
    -> "Content-Type: text/html;charset=ISO-8859-1\r\n"
    -> "Content-Length: 320\r\n"
    -> "Date: Mon, 06 Sep 2021 19:02:08 GMT\r\n"
    -> "Connection: close\r\n"
    -> "Server: \r\n"
    -> "Set-Cookie: UqZBpD3n=v1I4cyJQ__N2M; Expires=Mon, 06-Sep-2021 19:03:38 GMT; Path=/; Secure; HttpOnly\r\n"
    -> "\r\n"
    response: {"folio_cdp":"095492846","auth":"928468","response":"approved","message":"0C- Pago aprobado (test)","id_comercio":"147","reference":"721","amount":"11.15","time":"19:02:08 06:09:2021","operation":"Authorize"}read 320 bytes
    Conn close
    opening connection to wpy.mitec.com.mx:443...
    opened
    starting SSL for wpy.mitec.com.mx:443...
    SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
    <- "POST /ModuloUtilWS/activeCDP.htm HTTP/1.1\r\nContent-Type: application/json\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: wpy.mitec.com.mx\r\nContent-Length: 359\r\n\r\n"
    <- "{\"payload\":\"<capture>{"operation":"Capture","commerce_id":"147","user":"IVCA33721","apikey":"[FILTERED]","testMode":"YES","transaction_id":"721","amount":"11.15","key_session":"[FILTERED]"}</capture><dataID>IVCA33721</dataID>\"}"
    -> "HTTP/1.1 200 \r\n"
    -> "Strict-Transport-Security: max-age=31536000;includeSubDomains\r\n"
    -> "X-Content-Type-Options: nosniff\r\n"
    -> "X-XSS-Protection: 1; mode=block\r\n"
    -> "Content-Type: text/html;charset=ISO-8859-1\r\n"
    -> "Content-Length: 280\r\n"
    -> "Date: Mon, 06 Sep 2021 19:02:08 GMT\r\n"
    -> "Connection: close\r\n"
    -> "Server: \r\n"
    -> "Set-Cookie: UqZBpD3n=v1JocyJQ__9tu; Expires=Mon, 06-Sep-2021 19:03:39 GMT; Path=/; Secure; HttpOnly\r\n"
    -> "\r\n"
    response: {"folio_cdp":"095492915","auth":"929151","response":"approved","message":"0C- ","id_comercio":"147","reference":"721","amount":"11.15","time":"19:02:09 06:09:2021","operation":"Capture"}read 280 bytes
    Conn close
    POST_SCRUBBED
  end
end
