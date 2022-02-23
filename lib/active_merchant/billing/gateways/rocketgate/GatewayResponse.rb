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

require "rexml/document"

module RocketGate
  class GatewayResponse

######################################################################
#
#	Define constant hash values.
#
######################################################################
#
    VERSION_INDICATOR = "version"
    ACS_URL = "acsURL"
    AUTH_NO = "authNo"
    AVS_RESPONSE = "avsResponse"
    BALANCE_AMOUNT = "balanceAmount"
    BALANCE_CURRENCY = "balanceCurrency"
    BANK_RESPONSE_CODE = "bankResponseCode"
    BILLING_ADDRESS = "billingAddress"
    BILLING_CITY = "billingCity"
    BILLING_COUNTRY = "billingCountry"
    BILLING_STATE = "billingState"
    BILLING_ZIPCODE = "billingZipCode"
    CARD_TYPE = "cardType"
    CARD_HASH = "cardHash"
    CARD_BIN = "cardBin"
    CARD_LAST_FOUR = "cardLastFour"
    CARD_EXPIRATION = "cardExpiration"
    CARD_COUNTRY = "cardCountry"
    CARD_REGION = "cardRegion"
    CARD_DEBIT_CREDIT = "cardDebitCredit"
    CARD_DESCRIPTION = "cardDescription"
    CARD_ISSUER_NAME = "cardIssuerName"
    CARD_ISSUER_PHONE = "cardIssuerPhone"
    CARD_ISSUER_URL = "cardIssuerURL"
    CAVV_RESPONSE = "cavvResponse"
    CUSTOMER_FIRSTNAME = "customerFirstName"
    CUSTOMER_LASTNAME = "customerLastName" 
    CVV2_CODE = "cvv2Code"
    EXCEPTION = "exception"
    ECI = "ECI"
    EMAIL = "email"
    IOVATION_TRACKING_NO = "IOVATIONTRACKINGNO"
    IOVATION_DEVICE = "IOVATIONDEVICE"
    IOVATION_RESULTS = "IOVATIONRESULTS"
    IOVATION_SCORE = "IOVATIONSCORE"
    IOVATION_RULE_COUNT = "IOVATIONRULECOUNT"
    IOVATION_RULE_TYPE_ = "IOVATIONRULETYPE_"
    IOVATION_RULE_REASON_ = "IOVATIONRULEREASON_"
    IOVATION_RULE_SCORE_ = "IOVATION_RULE_SCORE_"
    JOIN_DATE = "joinDate"
    JOIN_AMOUNT = "joinAmount"
    LAST_BILLING_DATE = "lastBillingDate"
    LAST_BILLING_AMOUNT = "lastBillingAmount"
    LAST_REASON_CODE = "lastReasonCode"
    MERCHANT_ACCOUNT = "merchantAccount"
    MERCHANT_CUSTOMER_ID = "merchantCustomerID"
    MERCHANT_INVOICE_ID = "merchantInvoiceID"
    MERCHANT_PRODUCT_ID = "merchantProductID"
    MERCHANT_SITE_ID = "merchantSiteID"
    PAREQ = "PAREQ"
    PAY_TYPE = "payType"
    PAY_HASH = "cardHash"
    PAY_LAST_FOUR = "cardLastFour"
    REASON_CODE = "reasonCode"
    REBILL_AMOUNT = "rebillAmount"
    REBILL_DATE = "rebillDate"
    REBILL_END_DATE = "rebillEndDate"
    REBILL_FREQUENCY = "rebillFrequency"
    REBILL_STATUS = "rebillStatus"
    RESPONSE_CODE = "responseCode"
    ROCKETPAY_INDICATOR = "rocketPayIndicator"
    TRANSACT_ID = "guidNo"
    SCRUB_RESULTS = "scrubResults"
    SETTLED_AMOUNT = "approvedAmount"
    SETTLED_CURRENCY = "approvedCurrency"


######################################################################
#
#	initialize() - Constructor for class.
#
######################################################################
#
    def initialize
      @parameterList = Hash.new			# Create empty hash
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
      @parameterList[key] = value		# Save new value
    end


######################################################################
#
#	Reset() - Clear all elements in a response.
#
######################################################################
#	
    def Reset
      @parameterList = Hash.new			# Create empty hash
    end


######################################################################
#
#	SetFromXML() - Set values in a response object
#		       using an XML document.
#
######################################################################
#
    def SetFromXML(xmlDocument)

#
#	Parse the elements from the XML document.
#
      begin
	xml = REXML::Document.new(xmlDocument)
	if root = REXML::XPath.first(xml, "/gatewayResponse")
	  root.elements.to_a.each do |node|
	    if (node.text != nil)
	      Set(node.name, node.text.strip)
	    end
	  end
	else

#
#	If there was a parsing error, set the error
#	codes and quit.
#
	  Set(EXCEPTION, xmlDocument)		# Return the XML
	  Set(RESPONSE_CODE, "3")		# Set system error
	  Set(REASON_CODE, "400")		# Invalid XML
	end

#
#	Catch parsing errors.
#
      rescue => ex
	Set(EXCEPTION, ex.message)		# Return error message
	Set(RESPONSE_CODE, "3")			# Set system error
	Set(REASON_CODE, "307")			# Bugcheck
      end
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
  end
end
