module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PerfectMoney
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          
          #The merchant’s PerfectMoney® account to which the payment is to be made. For example U9007123.
          mapping :account, 'PAYEE_ACCOUNT'
          
          #The name the merchant wishes to have displayed as the Payee on the PerfectMoney® payment form. An example field value is “My company, Inc.”.
          mapping :merchant_name, 'PAYEE_NAME'
          
          #The total amount of the purchase, in payment units (see below). Example values are 355.23 (for currencies like EUR or USD) and 19 (for GOLD only integer values are accpetable). 
          mapping :amount, 'PAYMENT_AMOUNT'
          
          #A designator which specifies the units in which the PAYMENT_AMOUNT value is expressed. Possible units: USD = US Dollars (USD) EUR = Euro OAU = Gold Troy oz Currency must correspond to account type you selected.
          mapping :currency, 'PAYMENT_UNITS'
          
          #(Optional) The value of this field can be used by the merchant for the order number, invoice identifier or any other reference string. This field is included in the MD5 message digest sent with payment acknowledgement. If the field in not present on the SCI entry form, the string “NULL” is used as its value when computing the MD5 message digest. 
          mapping :order, 'PAYMENT_ID'
          
          # (Optional) Controls whether and how payment status is returned by the PerfectMoney server to the merchant. 
          # No payment status is returned to the merchant if this field is not present or if its value is set to “NULL”. Otherwise the field value determines how and where the payment status is sent as described below.
          # Payment status in e-mail:
          # Payment status is sent in the form of e-mail when the value field is set to an e-mail address prefixed by “mailto:”. An example value field for this method is “mailto:info@shop.com”. Note that “mailto:” must be specified in lower case, however case is unimportant for the e-mail address itself.
          # Payment status in Form Post:
          # Payment status is submitted as an HTML form if the URL is specified as the value of the STATUS_URL field. The form is submitted to the URL with the POST method by the PerfectMoney server upon successful completion of an PerfectMoney payment. Thus, the target URL would normally be that of a cgi program or other form processor. This URL can specify a secure protocol such as https. An example value for having the payment status sent as a form is:
          # ”https://www.shop.com/orderpayment.asp”
          # The only legal URL types are “mailto:”, “http://”, and “https://”. Non-standard port numbers are not supported.
          mapping :status_url, 'STATUS_URL'
          
          #The URL to which a form is submitted or to which a hypertext link is taken by the buyer’s browser upon successful PerfectMoney® payment to the merchant. This is the buyer’s normal return path into the merchant’s shopping cart system. This URL can specify a secure protocol such as https. By default, this URL is assumed to be a target for a form POST operation, however other actions are possible when the optional PAYMENT_URL_METHOD field is specified (see below).
          mapping :success_url, 'PAYMENT_URL'
          
          #(Optional) This field controls how the value for the PAYMENT_URL field is used. The PAYMENT_URL_METHOD field value can be “POST” or “GET” or “LINK”, and must be specified in upper case. The actions taken for each are as follows:
          #“POST” – The payment status is sent to the PAYMENT URL in an HTML form using the POST method.
          #“GET” - The payment status is sent to the PAYMENT URL in an HTML form using the GET method.
          #“LINK” – When payment is made, a simple hypertext link is used to return to the PAYMENT_URL. This option allows merchants that are unable to host cgi's on their web site  to have a clean link back to their sites html pages (avoiding http 405 errors).
          mapping :payment_url_method, 'PAYMENT_URL_METHOD'

          #The URL to which a form is submitted or to which a hypertext link is taken by the buyer’s browser upon an unsuccessful or cancelled PerfectMoney® payment to the merchant. This is the buyer’s alternate return path into the merchant’s shopping cart system when an PerfectMoney® payment cannot be made or is cancelled.
          #Note that this URL can be the same as that provided for PAYMENT_URL, since status is provided on the form in hidden text fields to distinguish between the two payment outcomes.
          #This URL can specify a secure protocol such as https.
          #By default, this URL is assumed to be a target for a form POST operation, however other actions are possible when the optional NOPAYMENT_URL_METHOD field is specified (see below).
          mapping :fail_url, 'NOPAYMENT_URL'

          #(Optional) This field controls how the value for the NOPAYMENT_URL field is used. The NOPAYMENT_URL_METHOD field value can be “POST” or “GET” or “LINK”, and must be specified in upper case. The actions taken for each are as follows:
          #“POST” – The unsuccessful status is sent to the NOPAYMENT URL in an HTML form using the POST method.
          #“GET” - The unsuccessful status is sent to the NOPAYMENT URL in an HTML form using the GET method.
          #“LINK” – upon an unsuccessful or cancelled PerfectMoney™ payment to the merchant, a simple hypertext link is used to pass control to the NOPAYMENT_URL. This option allows merchants that are unable to host cgi's on their web site  to have a clean link back to their sites html pages (avoiding http 405 errors).
          mapping :nopayment_url_method, 'NOPAYMENT_URL_METHOD'

          #A space delimited list of hidden text field names used exclusively by the merchant for his own purposes. An example value is:
          #“KEY_CODE CUSTOMER_ID BATCH_NUM”. 
          #If the merchant requires no additional fields then the value of BAGGAGE_FIELDS should be set to an empty string (“”). The total number of characters in all baggage fields and names combined should not exceed 4000 bytes.
          mapping :baggage_fields, 'BAGGAGE_FIELDS'

          #(Optional) If this input field is present, the Memo area of the PerfectMoney payment form is pre-filled in with its value. At most, 100 characters can be entered into the memo field. (The customer is free to edit the memo, so its content should not be relied upon to stay unchanged.) 
          mapping :suggested_memo, 'SUGGESTED_MEMO'

          #(Optional) If this input field is present and not empty (for example its value is 1), user can not edit memo field during payment process. 
          mapping :suggested_memo_nochange, 'SUGGESTED_MEMO_NOCHANGE'
          
          #(Optional) If this input field is present, the PerfectMoney account number from which the payment will be made is fixed to this number and cannot be edited/changed by the customer. Use it if you must be paid from a certain account number. Account numbers can range from 1 to 9 decimal digits.
          mapping :payer_account, 'FORCED_PAYER_ACCOUNT'

          #(Optional)  A comma delimited list of available payment methods. Your customer will have ability to choose one of them on the first step of payment process. An example value is:
          #“account, voucher, sms, wire” (all available methods)
          #Possible values:
          #“account” – Perfect Money account to account payment (default);
          #“voucher” – payment using Perfect Money e-Voucher or Prepaid card;
          #“sms” – payment with sending special SMS message(s) from mobile phone;
          #“wire” – payment via international bank wire transfer.
          #“all” – make all currently existing payment methods available for choosing (actually the same as “account, voucher, sms, wire”).
          #If this field is not present all payment methods are available.
          # AVAILABLE_PAYMENT_METHODS
          
          #(Optional) This field indicates which payment method is selected by default when your customer comes to our merchant.
          #If this field is not present “account” method is selected by default.
          # DEFAULT_PAYMENT_METHOD
          
          #(Optional) This field is to force user pay by one given payment method only. For example if it is set to “sms”, your customer  will be redirected to SMS payment without displaying payment method choose form.
          # FORCED_PAYMENT_METHOD
          
          #(Optional) This field is to set SCI interface language. 
          #Possible values: en_US - U.S. English, de_DE - Deutsch, el_GR - Ελληνικά, zh_CN - 中文, ja_JP - 日本語, ko_KR - 한국어, es_ES - Español, fr_FR - Français, ru_RU - Русский, uk_UA - Українська, it_IT - Italiano, pt_PT - Português, ar_AE - العربية, fa_IR - فارسی, th_TH - ไทย, id_ID - Indonesia, ms_MY - Malaysian, tr_TR - Türkçe, pl_PL - Polski, ro_RO - Român
          #By default language is set according to browser settings. So you can leave this field empty.
          mapping :locale, 'INTERFACE_LANGUAGE'

        end
      end
    end
  end
end