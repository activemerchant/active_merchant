#
# Copyright notice:
# (c) Copyright 2020 RocketGate
# All rights reserved.
#
# The copyright notice must not be removed without specific, prior
# written permission from RocketGate.
#
# This software is protected as an unpublished work under the U.S. copyright
# laws. The above copyright notice is not intended to effect a publication of
# this work.
# This software is the confidential and proprietary information of RocketGate.
# Neither the binaries nor the source code may be redistributed without prior
# written permission from RocketGate.
#
# The software is provided "as-is" and without warranty of any kind, express, implied
# or otherwise, including without limitation, any warranty of merchantability or fitness
# for a particular purpose.  In no event shall RocketGate be liable for any direct,
# special, incidental, indirect, consequential or other damages of any kind, or any damages
# whatsoever arising out of or in connection with the use or performance of this software,
# including, without limitation, damages resulting from loss of use, data or profits, and
# whether or not advised of the possibility of damage, regardless of the theory of liability.
#

module RocketGate
  class GatewayRequest

######################################################################
#
#	Define constant hash values.
#
######################################################################
#
    VERSION_INDICATOR = "version"
    VERSION_NUMBER = "R3.3"

    AFFILIATE = "affiliate"
    AMOUNT = "amount"
    AVS_CHECK = "avsCheck"
    BILLING_ADDRESS = "billingAddress"
    BILLING_CITY = "billingCity"
    BILLING_COUNTRY = "billingCountry"
    BILLING_STATE = "billingState"
    BILLING_TYPE = "billingType"
    BILLING_ZIPCODE = "billingZipCode"
    BROWSER_USER_AGENT = "browserUserAgent"
    BROWSER_ACCEPT_HEADER = "browserAcceptHeader"
    CAPTURE_DAYS = "captureDays"
    CARDNO = "cardNo"
    CARD_HASH = "cardHash"
    CLONE_CUSTOMER_RECORD = "cloneCustomerRecord"
    CLONE_TO_CUSTOMER_ID = "cloneToCustomerID"
    CURRENCY = "currency"
    CUSTOMER_FIRSTNAME = "customerFirstName"
    CUSTOMER_LASTNAME = "customerLastName"
    CUSTOMER_PASSWORD = "customerPassword"
    CUSTOMER_PHONE_NO = "customerPhoneNo"
    CVV2 = "cvv2"
    CVV2_CHECK = "cvv2Check"
    EMAIL = "email"
    EMBEDDED_FIELDS_TOKEN = "embeddedFieldsToken"
    EXPIRE_MONTH = "expireMonth"
    EXPIRE_YEAR = "expireYear"
    GENERATE_POSTBACK = "generatePostback"
    IOVATION_BLACK_BOX = "iovationBlackBox"
    IOVATION_RULE = "iovationRule"
    IPADDRESS = "ipAddress"
    MERCHANT_ACCOUNT = "merchantAccount"
    MERCHANT_CUSTOMER_ID = "merchantCustomerID"
    MERCHANT_DESCRIPTOR = "merchantDescriptor"
    MERCHANT_DESCRIPTOR_CITY = "merchantDescriptorCity"
    MERCHANT_INVOICE_ID = "merchantInvoiceID"
    MERCHANT_ID = "merchantID"
    MERCHANT_PASSWORD = "merchantPassword"
    MERCHANT_PRODUCT_ID = "merchantProductID"
    MERCHANT_SITE_ID = "merchantSiteID"
    OMIT_RECEIPT = "omitReceipt"
    PARES = "PARES"
    PARTIAL_AUTH_FLAG = "partialAuthFlag"
    PAYINFO_TRANSACT_ID = "payInfoTransactID"
    PAY_HASH = "cardHash"
    REBILL_FREQUENCY = "rebillFrequency"
    REBILL_AMOUNT = "rebillAmount"
    REBILL_START = "rebillStart"
    REBILL_END_DATE = "rebillEndDate"
    REBILL_COUNT = "rebillCount"
    REFERENCE_GUID = "referenceGUID"
    REFERRING_MERCHANT_ID = "referringMerchantID"
    REFERRED_CUSTOMER_ID = "referredCustomerID"
    SCRUB = "scrub"
    SCRUB_ACTIVITY = "scrubActivity"
    SCRUB_NEGDB = "scrubNegDB"
    SCRUB_PROFILE = "scrubProfile"
    THREATMETRIX_SESSION_ID = "threatMetrixSessionID"
    TRANSACT_ID = "referenceGUID"
    TRANSACTION_TYPE = "transactionType"
    UDF01 = "udf01"
    UDF02 = "udf02"
    USE_3D_SECURE = "use3DSecure"
    USERNAME = "username"
    XSELL_MERCHANT_ID = "xsellMerchantID"
    XSELL_CUSTOMER_ID = "xsellCustomerID"
    XSELL_REFERENCE_XACT = "xsellReferenceXact"
    _3D_CHECK = "ThreeDCheck"
    _3D_ECI = "ThreeDECI"
    _3D_CAVV_UCAF = "ThreeDCavvUcaf"
    _3D_XID = "ThreeDXID"
    FAILED_SERVER = "failedServer"
    FAILED_GUID = "failedGUID"
    FAILED_RESPONSE_CODE = "failedResponseCode"
    FAILED_REASON_CODE = "failedReasonCode"

    GATEWAY_CONNECT_TIMEOUT = "gatewayConnectTimeout"
    GATEWAY_READ_TIMEOUT = "gatewayReadTimeout"


######################################################################
#
#	initialize() - Constructor for class.
#
######################################################################
#
    def initialize
      @parameterList = Hash.new			# Create empty hash
      self.Set(VERSION_INDICATOR, VERSION_NUMBER)
      super					# Call superclass
    end


######################################################################
#
#	Set() - Set a value in the parameter list.
#
######################################################################
#
    def Set(key, value)
      @parameterList.delete key			# Delete existing key
      if value != nil				# Have a value?
        @parameterList[key] = value		# Save new value
      end
    end


######################################################################
#
#	Clear() - Clear a value in the parameter list.
#
######################################################################
#
    def Clear(key)
      @parameterList.delete key			# Delete existing key
    end


######################################################################
#
#	Get() - Get a value from the parameter list.
#
######################################################################
#
    def Get(key)
      return @parameterList[key]		# Return desired element
    end


######################################################################
#
#	ToXML() - Create an XML document from the hash list.
#
######################################################################
#
    def ToXML

#
#	Build the document header.
#
      xmlDocument = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
      xmlDocument.concat("<gatewayRequest>")

#
#	Loop over each key-value pairs.
#
      @parameterList.each_pair do | key, value |
	key = key.to_s
	value = value.to_s
#
#	Open a tag for the key.
#
	xmlDocument.concat("<");
	xmlDocument.concat(key)
	xmlDocument.concat(">");

#
#	Clean up the value and add it to the tag.
#
	value = value.gsub("&", "&amp;")	# Replace &
	value = value.gsub("<", "&lt;")		# Replace <
	value = value.gsub(">", "&gt;")		# Replace >
	xmlDocument.concat(value)

#
#
#	Add the closing tag for this element.
#
	xmlDocument.concat("</");
	xmlDocument.concat(key)
	xmlDocument.concat(">");
      end

#
#	Close and return the document.
#
      xmlDocument.concat("</gatewayRequest>")	# Close document
      return xmlDocument			# Final document
    end
  end
end

