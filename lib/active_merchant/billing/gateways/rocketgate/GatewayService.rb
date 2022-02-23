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

require "net/http"
require "net/https"
require File.dirname(__FILE__) + '/GatewayRequest'
require File.dirname(__FILE__) + '/GatewayResponse'

module RocketGate
  class GatewayService

######################################################################
#
#	Define constants
#
######################################################################
#
    ROCKETGATE_SERVLET = "/gateway/servlet/ServiceDispatcherAccess"
    ROCKETGATE_CONNECT_TIMEOUT = 10
    ROCKETGATE_READ_TIMEOUT = 90
    ROCKETGATE_PROTOCOL = "https"
    ROCKETGATE_PORTNO = "443"
    ROCKETGATE_USER_AGENT = "RG Client - Ruby " + GatewayRequest::VERSION_NUMBER;

    LIVE_HOST = "gateway.rocketgate.com"
    LIVE_HOST_16 = "gateway-16.rocketgate.com"
    LIVE_HOST_17 = "gateway-17.rocketgate.com"
    TEST_HOST = "dev-gateway.rocketgate.com"


######################################################################
#
#	initialize() - Constructor for class.
#
######################################################################
#
    def initialize
      @testMode = false				# Default to live
      @rocketGateDNS = LIVE_HOST
      @rocketGateHost = [ LIVE_HOST_16, LIVE_HOST_17 ]
      @rocketGateServlet = ROCKETGATE_SERVLET
      @rocketGateProtocol = ROCKETGATE_PROTOCOL
      @rocketGatePortNo = ROCKETGATE_PORTNO
      @rocketGateConnectTimeout = ROCKETGATE_CONNECT_TIMEOUT
      @rocketGateReadTimeout = ROCKETGATE_READ_TIMEOUT
      super					# Call superclass
    end


######################################################################
#
#	SetTestMode() - Select test/development mode.
#
######################################################################
#
    def SetTestMode(yesNo)
      if yesNo					# Setting test mode?
	@testMode = true;			# Set to test mode
        @rocketGateHost = [ TEST_HOST ]		# Point to dev hosts
        @rocketGateDNS = TEST_HOST
      else
	@testMode = false;			# Set to live mode
	@rocketGateHost = [ LIVE_HOST_16, LIVE_HOST_17 ]
        @rocketGateDNS = LIVE_HOST
      end
    end


######################################################################
#
#	SetHost() - Set the host used by the service
#
######################################################################
#
    def SetHost(hostName)
      @rocketGateHost = [ hostName ]		# Use this host
      @rocketGateDNS = hostName
    end


######################################################################
#
#	SetProtocol() - Set the communications protocol used
#			by the service.
#
######################################################################
#
    def SetProtocol(protocol)
      @rocketGateProtocol = protocol		# HTTP, HTTPS, etc
    end


######################################################################
#
#	SetPortNo() - Set the port number used by the service.
#
######################################################################
#
    def SetPortNo(portNo)
      @rocketGatePortNo = portNo		# IP port
    end


######################################################################
#
#	SetServlet() - Set servlet used by the service.
#
######################################################################
#
    def SetServlet(servlet)
      @rocketGateServlet = servlet		# End point
    end


######################################################################
#
#	SetConnectTimeout() - Set connection timeout
#
######################################################################
#
    def SetConnectTimeout(timeout)
      if (timeout.to_i > 0)			# Have a real value?
        @rocketGateConnectTimeout = timeout.to_i
      end
    end


######################################################################
#
#	SetReadTimeout() - Set read timeout
#
######################################################################
#
    def SetReadTimeout(timeout)
      if (timeout.to_i > 0)			# Have a real value?
        @rocketGateReadTimeout = timeout.to_i	# Number of seconds
      end
    end


######################################################################
#
#	SendTransaction() - Send a transaction to a named host.
#			    
######################################################################
#
    def SendTransaction(serverName, request, response)

#
#	Gather overrides for transaction.
#
      urlServlet = request.Get("gatewayServlet")
      urlProtocol = request.Get("gatewayProtocol")
      urlPortNo = request.Get("portNo")

#
#	Determine the final servlet name.
#
      if urlServlet == nil
	urlServlet = @rocketGateServlet
      end

#
#	Determine the final protocol.
#
      if urlProtocol == nil
	urlProtocol = @rocketGateProtocol
      end

#
#	Determine the final port number.
#
      if urlPortNo == nil
	urlPortNo = @rocketGatePortNo
      end

#
#	Get the connection timeout.
#
      connectTimeout = request.Get("gatewayConnectTimeout")
      if ((connectTimeout == nil) || (connectTimeout.to_i <= 0))
	connectTimeout = @rocketGateConnectTimeout
      end

#
#	Get the read timeout.
#
      readTimeout = request.Get("gatewayReadTimeout")
      if ((readTimeout == nil) || (readTimeout.to_i <= 0))
	readTimeout = @rocketGateReadTimeout
      end

#
#	Prepare the values that will go into post
#
      begin
	response.Reset				# Clear any response data
	requestXML = request.ToXML		# Get message string
	headers = { 'Content-Type' => 'text/xml', 'User-Agent' => ROCKETGATE_USER_AGENT }

#
#	Create the HTTP handler for the post.
#
	http = Net::HTTP.new(serverName, urlPortNo)
	http.open_timeout = connectTimeout	# Setup connection timeout
	http.read_timeout = readTimeout		# Setup operation timeout

#
#	If we are doing HTTPS, we need to setup SSL.
#
	urlProtocol = urlProtocol.upcase	# Change to caps
	if (urlProtocol == "HTTPS")		# Need HTTPS?
	  http.use_ssl = true			# Required SSL
	  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
	end

#
#	Perform the posting.
#
	results = http.request_post(urlServlet, requestXML, headers)
	body = results.body			# Get the response data

#
#	Check if we were unable to connect.
#
      rescue Errno::ECONNREFUSED => ex
	response.Set(GatewayResponse::EXCEPTION, ex.message)
	response.Set(GatewayResponse::RESPONSE_CODE, "3")
	response.Set(GatewayResponse::REASON_CODE, "301")
	return "3"				# System error

#
#	Check if there was some type of timeout.
#
      rescue Timeout::Error => ex
	response.Set(GatewayResponse::EXCEPTION, ex.message)
	response.Set(GatewayResponse::RESPONSE_CODE, "3")
	response.Set(GatewayResponse::REASON_CODE, "303")
	return "3"				# System error

#
#	Catch all other errors.
#
      rescue => ex				# Default handler
	response.Set(GatewayResponse::EXCEPTION, ex.message)
	response.Set(GatewayResponse::RESPONSE_CODE, "3")
	response.Set(GatewayResponse::REASON_CODE, "304")
	return "3"				# System error
      end

#
#	Parse the response XML and return the response code.
#
      response.SetFromXML(body)			# Set from response body
      responseCode = response.Get(GatewayResponse::RESPONSE_CODE)
      if (responseCode == nil)			# Don't have one?
	responseCode = "3"			# System error
	response.Set(GatewayResponse::EXCEPTION, body)
        response.Set(GatewayResponse::RESPONSE_CODE, "3")
        response.Set(GatewayResponse::REASON_CODE, "400") 
      end
      return responseCode			# Give back results
    end


######################################################################
#
#	PerformTransaction() - Perform the transaction described
#			       in a gateway request.
#
######################################################################
#
    def PerformTransaction(request, response)

#
#	If the request specifies a server name, use it.
#	Otherwise, use the default.
#
      serverName = request.Get("gatewayServer")	# Get server name
      if (serverName != nil)			# Override?
	serverName = [ serverName ]		# Use this name
      else
        serverName = @rocketGateHost		# Use default list
      end

#
#	Clear any error tracking that may be leftover.
#
      request.Clear(GatewayRequest::FAILED_SERVER);
      request.Clear(GatewayRequest::FAILED_RESPONSE_CODE);
      request.Clear(GatewayRequest::FAILED_REASON_CODE);
      request.Clear(GatewayRequest::FAILED_GUID);

#
#	Randomly pick an endpoint.
#
      if (serverName.length > 1)		# Have multiples?
	index = rand(serverName.length)		# Pick random server
	if (index > 0)				# Want to change?
	  swapper = serverName[0]		# Save the first one
	  serverName[0] = serverName[index]	# Move to first
	  serverName[index] = swapper		# And swap
	end
      end

#
#	Loop over the hosts and try to send the transaction
#	to each host in the list until it succeeds or fails
#	due to an unrecoverable error.
#
      index = 0					# Start at first position
      while index < serverName.length do	# Loop over list
	results = self.SendTransaction(serverName[index], request, response)

#
#	If the transaction was successful, we are done
#
	if results == "0"			# Success?
	  return true				# All done
	end 

#
#	If the transaction is not recoverable, quit.
#
	if results != "3"			# Unrecoverable?
	  return false				# All done
	end 

#
#	Save any errors in the response so they can be
# 	transmitted along with the next request.
#
	request.Set(GatewayRequest::FAILED_SERVER, serverName[index]);
	request.Set(GatewayRequest::FAILED_RESPONSE_CODE,
                    response.Get(GatewayResponse::RESPONSE_CODE));
	request.Set(GatewayRequest::FAILED_REASON_CODE,
                    response.Get(GatewayResponse::REASON_CODE));
	request.Set(GatewayRequest::FAILED_GUID,
                    response.Get(GatewayResponse::TRANSACT_ID));
	index = index + 1			# Next index
      end
    end


######################################################################
#
#	PerformTargetedTransaction() - Send a transaction to a
#				       server based upon the GUID.
#
######################################################################
#
    def PerformTargetedTransaction(request, response)

#
#	Clear any error tracking that may be leftover.
#
      request.Clear(GatewayRequest::FAILED_SERVER);
      request.Clear(GatewayRequest::FAILED_RESPONSE_CODE);
      request.Clear(GatewayRequest::FAILED_REASON_CODE);
      request.Clear(GatewayRequest::FAILED_GUID);

#
#	This transaction must go to the host that processed a
#	previous referenced transaction.  Get the GUID of the
#	reference transaction.
#
      referenceGUID = request.Get(GatewayRequest::REFERENCE_GUID)
      if (referenceGUID == nil)			# Don't have reference?
	response.Set(GatewayResponse::RESPONSE_CODE, "4")
	response.Set(GatewayResponse::REASON_CODE, "410")
	return false				# And quit
      end

#
#	Strip off the bits that indicate which server should
#	be used.
#
      siteString = "0x"				# Value is hex
      if (referenceGUID.length > 15)		# Server 16 and above?
	siteString.concat(referenceGUID[0,2])	# Get first two digits
      else
	siteString.concat(referenceGUID[0,1])	# Get first digit only
      end

#
#	Try to turn the site string into a number.
#
      begin
        siteNo = Integer(siteString)		# Convert to site number
      rescue
	response.Set(GatewayResponse::RESPONSE_CODE, "4")
	response.Set(GatewayResponse::REASON_CODE, "410")
	return false				# And quit
      end

#
#	Build the hostname to which the transaction should
#	be directed.
#
      serverName = request.Get("gatewayServer") # Get server name
      if (serverName == nil)			# Don't have one?
	serverName = @rocketGateDNS		# Start with default
	separator = serverName.index(".")	# Find first .
	if ((separator != nil) && (separator > 0))
	  prefix = serverName[0, separator]	# Get the prefix
	  prefix.concat("-")			# Add separator
	  prefix.concat(siteNo.to_s)		# Add site number
	  prefix.concat(serverName[separator, serverName.length])
	  serverName = prefix			# Full server name
	end
      end

#
#	Send the transaction to the specified host.
#
      results = self.SendTransaction(serverName, request, response)
      if results == "0"				# Success?
	return true				# All done
      end
      return false				# Failed
    end


######################################################################
#
#	PerformConfirmation() - Perform the confirmation pass that
#				tells the server we have received
#				the transaction reply.
#
######################################################################
#
    def PerformConfirmation(request, response)

#
#	Verify that we have a transaction ID for the
#	confirmation message.
#
      confirmGUID = response.Get(GatewayResponse::TRANSACT_ID)
      if (confirmGUID == nil)			# Don't have reference?
	response.Set(GatewayResponse::EXCEPTION,
		     "BUG-CHECK - Missing confirmation GUID")
	response.Set(GatewayResponse::RESPONSE_CODE, "3")
	response.Set(GatewayResponse::REASON_CODE, "307")
	return false				# And quit
      end

#
#	Add the GUID to the request and send it back to the
#	original server for confirmation.
#
      confirmResponse = GatewayResponse.new	# Need a new response object
      request.Set(GatewayRequest::TRANSACTION_TYPE, "CC_CONFIRM")
      request.Set(GatewayRequest::REFERENCE_GUID, confirmGUID)
      results = self.PerformTargetedTransaction(request, confirmResponse)
      if (results)				# Success?
	return true				# Yes - We are done
      end

#
#	If the confirmation failed, copy the reason and response code
#	into the original response object to override the success.
#
      response.Set(GatewayResponse::RESPONSE_CODE, 
			confirmResponse.Get(GatewayResponse::RESPONSE_CODE))
      response.Set(GatewayResponse::REASON_CODE, 
			confirmResponse.Get(GatewayResponse::REASON_CODE))
      return false				# And quit
    end


######################################################################
#
#	PerformAuthOnly() - Perform an auth-only transaction.
#
######################################################################
#
    def PerformAuthOnly(request, response)
      request.Set(GatewayRequest::TRANSACTION_TYPE, "CC_AUTH");
      results = self.PerformTransaction(request, response)
      if results				# Success?
	results = self.PerformConfirmation(request, response)
      end
      return results				# Return results
    end


######################################################################
#
#	PerformTicket() - Perform a Ticket operation for a previous
#			  auth-only transaction.
#
######################################################################
#
    def PerformTicket(request, response)
      request.Set(GatewayRequest::TRANSACTION_TYPE, "CC_TICKET");
      results = self.PerformTargetedTransaction(request, response)
      return results				# Return results
    end


######################################################################
#
#	PerformPurchase() - Perform a complete purchase transaction.
#
######################################################################
#
    def PerformPurchase(request, response)
      request.Set(GatewayRequest::TRANSACTION_TYPE, "CC_PURCHASE");
      results = self.PerformTransaction(request, response)
      if results				# Success?
	results = self.PerformConfirmation(request, response)
      end
      return results				# Return results
    end


######################################################################
#
#	PerformCredit() - Perform a Credit operation for a previous
#			  transaction.
#
######################################################################
#
    def PerformCredit(request, response)
      request.Set(GatewayRequest::TRANSACTION_TYPE, "CC_CREDIT");

#
#	If this is a reference GUID, send the transaction to
#	the appropriate server.  Otherwise use the normal
#	transaction distribution.
#
      referenceGUID = request.Get(GatewayRequest::REFERENCE_GUID)
      if (referenceGUID != nil)			# Have reference?
        results = self.PerformTargetedTransaction(request, response)
      else
        results = self.PerformTransaction(request, response)
      end
      return results				# Return results
    end


######################################################################
#
#	PerformVoid() - Perform a Void operation for a previous
#			transaction.
#
######################################################################
#
    def PerformVoid(request, response)
      request.Set(GatewayRequest::TRANSACTION_TYPE, "CC_VOID");
      results = self.PerformTargetedTransaction(request, response)
      return results				# Return results
    end


######################################################################
#
#	PerformCardScrub() - Perform scrubbing on a card/customer
#
######################################################################
#
    def PerformCardScrub(request, response)
      request.Set(GatewayRequest::TRANSACTION_TYPE, "CARDSCRUB");
      results = self.PerformTransaction(request, response)
      return results				# Return results
    end


######################################################################
#
#	PerformRebillCancel() - Schedule cancellation of rebilling.
#
######################################################################
#
    def PerformRebillCancel(request, response)
      request.Set(GatewayRequest::TRANSACTION_TYPE, "REBILL_CANCEL");
      results = self.PerformTransaction(request, response)
      return results				# Return results
    end


######################################################################
#
#	PerformRebillUpdate() - Update terms of a rebilling.
#
######################################################################
#
    def PerformRebillUpdate(request, response)
      request.Set(GatewayRequest::TRANSACTION_TYPE, "REBILL_UPDATE");

#
#	If there is no prorated charge, just perform the update.
#
      amount = request.Get(GatewayRequest::AMOUNT)
      if ((amount == nil) || (amount.to_f <= 0.0))
        results = self.PerformTransaction(request, response)
        return results				# Return results
      end

#
#	If there is a charge, perform the update and confirm
#	the charge.
#
      results = self.PerformTransaction(request, response)
      if results				# Success?
	results = self.PerformConfirmation(request, response)
      end
      return results				# Return results
    end

######################################################################
#
#   PerformLookup() - Lookup previous transaction.
#
######################################################################
#
    def PerformLookup(request, response)
      request.Set(GatewayRequest::TRANSACTION_TYPE, "LOOKUP");

      referenceGUID = request.Get(GatewayRequest::REFERENCE_GUID)

      if (referenceGUID != nil)			# Have reference?
        results = self.PerformTargetedTransaction(request, response)
      else
        results = self.PerformTransaction(request, response)
      end
    end

######################################################################
#
#   GenerateXsell() - Add an entry to the XsellQueue.
#
######################################################################
#
    def GenerateXsell(request, response)
      request.Set(GatewayRequest::TRANSACTION_TYPE, "GENERATEXSELL");
      request.Set(GatewayRequest::REFERENCE_GUID, request.Get(GatewayRequest::XSELL_REFERENCE_XACT) );

      referenceGUID = request.Get(GatewayRequest::REFERENCE_GUID)
      if (referenceGUID != nil)			# Have reference?
        results = self.PerformTargetedTransaction(request, response)
      else
        results = self.PerformTransaction(request, response)
      end
    end
#
  end
end

