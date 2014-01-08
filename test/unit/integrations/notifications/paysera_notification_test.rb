require 'test_helper'

class PayseraNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @order_id = '26'
    @project_id = '31530'
    @request_id = '46516962'
    @project_password = '8c5ebe834bb61a2e5ab8ef38f8d940f3'

    @paysera = Paysera::Notification.new(raw_data, :credential2 => @project_password)

    certificate_mock = OpenSSL::X509::Certificate.new public_key_mock_string
    Paysera::Notification.any_instance.stubs(:get_public_key).returns(certificate_mock.public_key)
  end

  def test_accessors
    assert @paysera.complete?
    assert_equal @order_id, @paysera.item_id
    assert_equal 'test@paysera.com', @paysera.payer_email
    assert_equal @project_password, @paysera.security_key
    assert_equal 1, @paysera.gross
    assert_equal 100, @paysera.gross_cents
    assert_equal 'USD', @paysera.currency
    assert @paysera.test?
    assert_equal 'Payment successful', @paysera.status
    assert_equal @request_id, @paysera.transaction_id
  end

  def test_credential2_required
    assert_raises ArgumentError do
      Paysera::Notification.new(raw_data, {})
    end

    assert_nothing_raised do
      Paysera::Notification.new(raw_data, :credential2 => @project_password)
    end
  end

  def test_respond_to_acknowledge
    assert @paysera.respond_to?(:acknowledge)
  end

  def test_acknowledgement
    assert @paysera.signature_v2_valid?
    assert @paysera.signature_v1_valid?
    assert @paysera.acknowledge
  end

  def test_wrong_signature_ss1
    @paysera_invalid = Paysera::Notification.new(raw_data_with_invalid_ss1, :credential2 => @project_password)
    assert !@paysera_invalid.signature_v1_valid?
    assert !@paysera_invalid.acknowledge
  end

  def test_wrong_signature_ss2
    @paysera_invalid = Paysera::Notification.new(raw_data_with_invalid_ss2, :credential2 => @project_password)
    assert !@paysera_invalid.signature_v2_valid?
    assert !@paysera_invalid.acknowledge
  end

  private
  def raw_data
    'data=b3JkZXJpZD0yNiZwcm9qZWN0aWQ9MzE1MzAmYW1vdW50PTEwMCZjdXJyZW5jeT1VU0QmdGVzdD0xJnZlcnNpb249MS42JnBfZmlyc3RuYW1lPUNvZHkmcF9sYXN0bmFtZT1GYXVzZXImcF9lbWFpbD10ZXN0JTQwcGF5c2VyYS5jb20mdHlwZT1FTUEmbGFuZz0mcGF5bWVudD1ub3JkJnBheXRleHQ9T3JkZXIrbm8lM0ErMjYrYXQraHR0cCUzQSUyRiUyRmxvY2FsaG9zdCtwcm9qZWN0LislMjhTZWxsZXIlM0ErRG1pdHJpanVzK0dsZXplcmlzJTI5JmNvdW50cnk9TFQmX2NsaWVudF9sYW5ndWFnZT1lbmcmc3RhdHVzPTEmcmVxdWVzdGlkPTQ2NTE2OTYyJm5hbWU9VUFCJnN1cmVuYW1lPU1vayVDNCU5N2ppbWFpLmx0JnBheWFtb3VudD0xMDAmcGF5Y3VycmVuY3k9VVNE&ss1=259163775d6cc3d91128da83317f670a&ss2=fettQwJaSyjHwzRZmfUZyJPCtnHg3jFCLyZxr5guzdlHLa9rDe-bwUN0lBa_GnHBcB89I7yHMS6elyW0tfnmVu0wKmx0ckUukCmu-HtEoIojY03cKwkYJ1P4MuCny-A7pbD8foE700ywuzxmcYqvYrrbfm05VxZZPFA0kbsW08M='
  end

  def raw_data_with_invalid_ss1
    'data=b3JkZXJpZD0yNSZwcm9qZWN0aWQ9MzE1MzAmYW1vdW50PTEwMDAmY3VycmVuY3k9VVNEJnRlc3Q9MSZ2ZXJzaW9uPTEuNiZwX2ZpcnN0bmFtZT1Db2R5JnBfbGFzdG5hbWU9RmF1c2VyJnBfZW1haWw9dGVzdCU0MHBheXNlcmEuY29tJnR5cGU9RU1BJmxhbmc9JnBheW1lbnQ9bm9yZCZwYXl0ZXh0PU9yZGVyK25vJTNBKzI1K2F0K2h0dHAlM0ElMkYlMkZsb2NhbGhvc3QrcHJvamVjdC4rJTI4U2VsbGVyJTNBK0RtaXRyaWp1cytHbGV6ZXJpcyUyOSZjb3VudHJ5PUxUJl9jbGllbnRfbGFuZ3VhZ2U9ZW5nJnN0YXR1cz0xJnJlcXVlc3RpZD00NjUxNjk2MCZuYW1lPVVBQiZzdXJlbmFtZT1Nb2slQzQlOTdqaW1haS5sdCZwYXlhbW91bnQ9MTAwMCZwYXljdXJyZW5jeT1VU0Q%3D&ss1=invalid_signature_v1&ss2=W3MPxh8LGMgCssle_ddPyldRezGn_yRHumAGTJimjn2L5Um6HdZ6K2BuBWUss1YNmNPaOWZmPdifboJraLbkswz7PAeAsv36lwd_oAMGUxHJPXahSYvt4guso2QTYf2laBvp1BZcDWNsvUdXcfoCfa4ZImLFohCY4gyiqijYfsQ%3D'
  end

  def raw_data_with_invalid_ss2
    'data=b3JkZXJpZD0yNSZwcm9qZWN0aWQ9MzE1MzAmYW1vdW50PTEwMDAmY3VycmVuY3k9VVNEJnRlc3Q9MSZ2ZXJzaW9uPTEuNiZwX2ZpcnN0bmFtZT1Db2R5JnBfbGFzdG5hbWU9RmF1c2VyJnBfZW1haWw9dGVzdCU0MHBheXNlcmEuY29tJnR5cGU9RU1BJmxhbmc9JnBheW1lbnQ9bm9yZCZwYXl0ZXh0PU9yZGVyK25vJTNBKzI1K2F0K2h0dHAlM0ElMkYlMkZsb2NhbGhvc3QrcHJvamVjdC4rJTI4U2VsbGVyJTNBK0RtaXRyaWp1cytHbGV6ZXJpcyUyOSZjb3VudHJ5PUxUJl9jbGllbnRfbGFuZ3VhZ2U9ZW5nJnN0YXR1cz0xJnJlcXVlc3RpZD00NjUxNjk2MCZuYW1lPVVBQiZzdXJlbmFtZT1Nb2slQzQlOTdqaW1haS5sdCZwYXlhbW91bnQ9MTAwMCZwYXljdXJyZW5jeT1VU0Q%3D&ss1=11e0110447bb8c0991a2d4ee2ed113cd&ss2=invalid_signature_v2'
  end

  def public_key_mock_string
    %q{-----BEGIN CERTIFICATE-----
        MIIECTCCA3KgAwIBAgIBADANBgkqhkiG9w0BAQUFADCBujELMAkGA1UEBhMCTFQx
        EDAOBgNVBAgTB1ZpbG5pdXMxEDAOBgNVBAcTB1ZpbG5pdXMxHjAcBgNVBAoTFVVB
        QiBFVlAgSW50ZXJuYXRpb25hbDEtMCsGA1UECxMkaHR0cDovL3d3dy5tb2tlamlt
        YWkubHQvYmFua2xpbmsucGhwMRkwFwYDVQQDExB3d3cubW9rZWppbWFpLmx0MR0w
        GwYJKoZIhvcNAQkBFg5wYWdhbGJhQGV2cC5sdDAeFw0wOTA3MjQxMjMxMTVaFw0x
        NzEwMTAxMjMxMTVaMIG6MQswCQYDVQQGEwJMVDEQMA4GA1UECBMHVmlsbml1czEQ
        MA4GA1UEBxMHVmlsbml1czEeMBwGA1UEChMVVUFCIEVWUCBJbnRlcm5hdGlvbmFs
        MS0wKwYDVQQLEyRodHRwOi8vd3d3Lm1va2VqaW1haS5sdC9iYW5rbGluay5waHAx
        GTAXBgNVBAMTEHd3dy5tb2tlamltYWkubHQxHTAbBgkqhkiG9w0BCQEWDnBhZ2Fs
        YmFAZXZwLmx0MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDeT23V/kNtf/hr
        Nae/ZsLfRZd8E+os6HZ9CbgvB+X659kBDBq5vjMDCVkY6sicn1fcFfuotEcbhKSK
        DrDAQ+DmCMm96C7A4gqCC5OqmINauxYDdbie7V9GJWnbRXDs/5Mu722f5TuOUG3H
        hN/vTg8uCxIrGIYv9idhvTbDyieVCwIDAQABo4IBGzCCARcwHQYDVR0OBBYEFI1V
        hRQeacLkR4OekokkQq0dFDAHMIHnBgNVHSMEgd8wgdyAFI1VhRQeacLkR4Oekokk
        Qq0dFDAHoYHApIG9MIG6MQswCQYDVQQGEwJMVDEQMA4GA1UECBMHVmlsbml1czEQ
        MA4GA1UEBxMHVmlsbml1czEeMBwGA1UEChMVVUFCIEVWUCBJbnRlcm5hdGlvbmFs
        MS0wKwYDVQQLEyRodHRwOi8vd3d3Lm1va2VqaW1haS5sdC9iYW5rbGluay5waHAx
        GTAXBgNVBAMTEHd3dy5tb2tlamltYWkubHQxHTAbBgkqhkiG9w0BCQEWDnBhZ2Fs
        YmFAZXZwLmx0ggEAMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADgYEAwIZw
        Rb2E//fmXrcO2hnUYaG9spg1xCvRVrlfasLRURzcwwyUpJian7+HTdTNhrMa0rHp
        NlS0iC8hx1Xfltql//lc7EoyyIRXrom4mijCFUHmAMvR5AmnBvEYAUYkLnd/QFm5
        /utEm5JsVM8LidCtXUppCehy1bqp/uwtD4b4F3c=
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE REQUEST-----
        MIIB+zCCAWQCAQAwgboxCzAJBgNVBAYTAkxUMRAwDgYDVQQIEwdWaWxuaXVzMRAw
        DgYDVQQHEwdWaWxuaXVzMR4wHAYDVQQKExVVQUIgRVZQIEludGVybmF0aW9uYWwx
        LTArBgNVBAsTJGh0dHA6Ly93d3cubW9rZWppbWFpLmx0L2JhbmtsaW5rLnBocDEZ
        MBcGA1UEAxMQd3d3Lm1va2VqaW1haS5sdDEdMBsGCSqGSIb3DQEJARYOcGFnYWxi
        YUBldnAubHQwgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBAN5PbdX+Q21/+Gs1
        p79mwt9Fl3wT6izodn0JuC8H5frn2QEMGrm+MwMJWRjqyJyfV9wV+6i0RxuEpIoO
        sMBD4OYIyb3oLsDiCoILk6qYg1q7FgN1uJ7tX0YladtFcOz/ky7vbZ/lO45QbceE
        3+9ODy4LEisYhi/2J2G9NsPKJ5ULAgMBAAGgADANBgkqhkiG9w0BAQUFAAOBgQAr
        GZJzT9Tzvo6t6/mOHr4NsdyVopQm0Ym0mwcrs+4qC4yfz0kj7STjcUnPlz1OP+Vp
        aPoe4aREKf58SAZGfZqeiYhl2IL7i3PoeN/DThSwcFcb3YFpMG9EkRDfC/c2H0x7
        GFYXlI9ODyfBPa02o44sQdqmdhCQCqvS5/5vhflJ9A==
-----END CERTIFICATE REQUEST-----}
  end
end
