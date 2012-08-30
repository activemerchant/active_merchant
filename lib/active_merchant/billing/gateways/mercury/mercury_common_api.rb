module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module MercuryCommonAPI
      def self.included(base)
        base.default_currency = 'USD'
      end

      ENVELOPE_NAMESPACES = { 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
                              'xmlns:soap' => "http://schemas.xmlsoap.org/soap/envelope/",
                              'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
                            }
                            
      SUCCESS_CODES = [ 'Approved', 'Success' ]
      FAILURE_CODES = [ 'Declined', 'Error' ]
      
      ERROR_CODES = {
        "009999" => "Unknown Error",
        "001001" => "General Failure",
        "001003" => "Invalid Command Format",
        "001004" => "Insufficient Fields",
        "001006" => "Global API Not Initialized",
        "001007" => "Timeout on Response",
        "001011" => "Empty Command String",
        "003002" => "In Process with server",
        "003003" => "Socket Error sending request.",
        "003004" => "Socket already open or in use",
        "003005" => "Socket Creation Failed",
        "003006" => "Socket Connection Failed",
        "003007" => "Connection Lost",
        "003008" => "TCP/IP Failed to Initialize",
        "003009" => "Control failed to find branded serial (password lookup failed)",
        "003010" => "Time Out waiting for server response",
        "003011" => "Connect Cancelled",
        "003012" => "128 bit CryptoAPI failed.",
        "003014" => "Threaded Auth Started Expect Response Event (Note it is possible the event could fire before the function returns.)",
        "003017" => "Failed to start Event Thread.",
        "003050" => "XML Parse Error",
        "003051" => "All Connections Failed",
        "003052" => "Server Login Failed",
        "003053" => "Initialize Failed",
        "004001" => "Global Response Length Error (Too Short)",
        "004002" => "Unable to Parse Response from Global (Indistinguishable)",
        "004003" => "Global String Error",
        "004004" => "Weak Encryption Request Not Supported",
        "004005" => "Clear Text Request Not Supported",
        "004011" => "Error Occurred While Decrypting Request",
        "004010" => "Unrecognized Request Format",
        "004017" => "Invalid Check Digit",
        "004018" => "Merchant ID Missing",
        "004019" => "TStream Type Missing",
        "004020" => "Could Not Encrypt Response- Call Provider",
        "100201" => "Invalid Transaction Type",
        "100202" => "Invalid Operator ID",
        "100203" => "Invalid Memo",
        "100204" => "Invalid Account Number",
        "100205" => "Invalid Expiration Date",
        "100206" => "Invalid Authorization Code",
        "100207" => "Invalid Reference Number",
        "100208" => "Invalid Authorization Amount",
        "100209" => "Invalid Cash Back Amount",
        "100210" => "Invalid Gratuity Amount",
        "100211" => "Invalid Purchase Amount",
        "100212" => "Invalid Magnetic Stripe Data",
        "100213" => "Invalid PIN Block Data",
        "100214" => "Invalid Derived Key Data",
        "100215" => "Invalid State Code",
        "100216" => "Invalid Date of Birth",
        "100217" => "Invalid Check Type",
        "100218" => "Invalid Routing Number",
        "100219" => "Invalid TranCode",
        "100220" => "Invalid Merchant ID",
        "100221" => "Invalid TStream Type",
        "100222" => "Invalid Batch Number",
        "100223" => "Invalid Batch Item Count",
        "100224" => "Invalid MICR Input Type",
        "100225" => "Invalid Driver's License",
        "100226" => "Invalid Sequence Number",
        "100227" => "Invalid Pass Data",
        "100228" => "Invalid Card Type"
      }
      CARD_CODES = {
        'visa' => 'VISA',
        'master' => 'M/C',
        'american_express' => 'AMEX',
        'discover' => 'DCVR',
        'diners_club' => 'DCLB',
        'jcb' => 'JCB'
      }
      
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end
      
      def test?
        @options[:test] || Base.gateway_mode == :test
      end
      
      def expdate(credit_card)
        year  = sprintf("%.4i", credit_card.year)
        month = sprintf("%.2i", credit_card.month)

        "#{month}#{year[-2..-1]}"
      end
      
    end
  end
end
