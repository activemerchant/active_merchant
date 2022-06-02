module QuickpayCommon
  MD5_CHECK_FIELDS = {
    3 => {
      authorize: %w(protocol msgtype merchant ordernumber amount
                    currency autocapture cardnumber expirationdate
                    cvd cardtypelock testmode),

      capture: %w(protocol msgtype merchant amount finalize transaction),

      cancel: %w(protocol msgtype merchant transaction),

      refund: %w(protocol msgtype merchant amount transaction),

      subscribe: %w(protocol msgtype merchant ordernumber cardnumber
                    expirationdate cvd cardtypelock description testmode),

      recurring: %w(protocol msgtype merchant ordernumber amount
                    currency autocapture transaction),

      status: %w(protocol msgtype merchant transaction),

      chstatus: %w(protocol msgtype merchant)
    },

    4 => {
      authorize: %w(protocol msgtype merchant ordernumber amount
                    currency autocapture cardnumber expirationdate cvd
                    cardtypelock testmode fraud_remote_addr
                    fraud_http_accept fraud_http_accept_language
                    fraud_http_accept_encoding fraud_http_accept_charset
                    fraud_http_referer fraud_http_user_agent apikey),

      capture: %w(protocol msgtype merchant amount finalize transaction apikey),

      cancel: %w(protocol msgtype merchant transaction apikey),

      refund: %w(protocol msgtype merchant amount transaction apikey),

      subscribe: %w(protocol msgtype merchant ordernumber cardnumber
                    expirationdate cvd cardtypelock description testmode
                    fraud_remote_addr fraud_http_accept fraud_http_accept_language
                    fraud_http_accept_encoding fraud_http_accept_charset
                    fraud_http_referer fraud_http_user_agent apikey),

      recurring: %w(protocol msgtype merchant ordernumber amount currency
                    autocapture transaction apikey),

      status: %w(protocol msgtype merchant transaction apikey),

      chstatus: %w(protocol msgtype merchant apikey)
    },

    5 => {
      authorize: %w(protocol msgtype merchant ordernumber amount
                    currency autocapture cardnumber expirationdate cvd
                    cardtypelock testmode fraud_remote_addr
                    fraud_http_accept fraud_http_accept_language
                    fraud_http_accept_encoding fraud_http_accept_charset
                    fraud_http_referer fraud_http_user_agent apikey),

      capture: %w(protocol msgtype merchant amount finalize transaction apikey),

      cancel: %w(protocol msgtype merchant transaction apikey),

      refund: %w(protocol msgtype merchant amount transaction apikey),

      subscribe: %w(protocol msgtype merchant ordernumber cardnumber
                    expirationdate cvd cardtypelock description testmode
                    fraud_remote_addr fraud_http_accept fraud_http_accept_language
                    fraud_http_accept_encoding fraud_http_accept_charset
                    fraud_http_referer fraud_http_user_agent apikey),

      recurring: %w(protocol msgtype merchant ordernumber amount currency
                    autocapture transaction apikey),

      status: %w(protocol msgtype merchant transaction apikey),

      chstatus: %w(protocol msgtype merchant apikey)
    },

    6 => {
      authorize: %w(protocol msgtype merchant ordernumber amount
                    currency autocapture cardnumber expirationdate cvd
                    cardtypelock testmode fraud_remote_addr
                    fraud_http_accept fraud_http_accept_language
                    fraud_http_accept_encoding fraud_http_accept_charset
                    fraud_http_referer fraud_http_user_agent apikey),

      capture: %w(protocol msgtype merchant amount finalize transaction
                  apikey),

      cancel: %w(protocol msgtype merchant transaction apikey),

      refund: %w(protocol msgtype merchant amount transaction apikey),

      subscribe: %w(protocol msgtype merchant ordernumber cardnumber
                    expirationdate cvd cardtypelock description testmode
                    fraud_remote_addr fraud_http_accept fraud_http_accept_language
                    fraud_http_accept_encoding fraud_http_accept_charset
                    fraud_http_referer fraud_http_user_agent apikey),

      recurring: %w(protocol msgtype merchant ordernumber amount currency
                    autocapture transaction apikey),

      status: %w(protocol msgtype merchant transaction apikey),

      chstatus: %w(protocol msgtype merchant apikey)
    },

    7 => {
      authorize: %w(protocol msgtype merchant ordernumber amount
                    currency autocapture cardnumber expirationdate cvd
                    acquirers cardtypelock testmode fraud_remote_addr
                    fraud_http_accept fraud_http_accept_language
                    fraud_http_accept_encoding fraud_http_accept_charset
                    fraud_http_referer fraud_http_user_agent apikey),

      capture: %w(protocol msgtype merchant amount finalize transaction
                  apikey),

      cancel: %w(protocol msgtype merchant transaction apikey),

      refund: %w(protocol msgtype merchant amount transaction apikey),

      subscribe: %w(protocol msgtype merchant ordernumber amount currency
                    cardnumber expirationdate cvd acquirers cardtypelock
                    description testmode fraud_remote_addr fraud_http_accept
                    fraud_http_accept_language fraud_http_accept_encoding
                    fraud_http_accept_charset fraud_http_referer
                    fraud_http_user_agent apikey),

      recurring: %w(protocol msgtype merchant ordernumber amount currency
                    autocapture transaction apikey),

      status: %w(protocol msgtype merchant transaction apikey),

      chstatus: %w(protocol msgtype merchant apikey)
    },

    10 => {
      authorize: %w(mobile_number acquirer autofee customer_id extras
                    zero_auth customer_ip),
      capture: %w(extras),
      cancel: %w(extras),
      refund: %w(extras),
      subscribe: %w(variables branding_id),
      authorize_subscription: %w(mobile_number acquirer customer_ip),
      recurring: %w(auto_capture autofee zero_auth)
    }
  }

  RESPONSE_CODES = {
    200 => 'OK',
    201 => 'Created',
    202 => 'Accepted',
    400 => 'Bad Request',
    401 => 'UnAuthorized',
    402 => 'Payment Required',
    403 => 'Forbidden',
    404 => 'Not Found',
    405 => 'Method Not Allowed',
    406 => 'Not Acceptable',
    409 => 'Conflict',
    500 => 'Internal Server Error'
  }

  def self.included(base)
    base.default_currency = 'DKK'
    base.money_format = :cents

    base.supported_countries = %w[DE DK ES FI FR FO GB IS NO SE]
    base.supported_cardtypes = %i[dankort forbrugsforeningen visa master
                                  american_express diners_club jcb maestro]
    base.homepage_url = 'http://quickpay.net/'
    base.display_name = 'QuickPay'
  end

  def expdate(credit_card)
    year  = format(credit_card.year, :two_digits)
    month = format(credit_card.month, :two_digits)

    "#{year}#{month}"
  end
end
