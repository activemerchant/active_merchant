module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module MyGate #:nodoc:
      
      # An object of this class is returned from <tt>MyGateGateway#security_auth</tt>.
      # This class handles the XML parsing for the API request.
      # 
      # ==== Properties
      # 
      # <tt>success</tt>                : <tt>true</tt> if the service returned a Result of 0
      # <tt>pa_response_status</tt>     : <tt>true</tt> if the cardholder is enrolled for 3D-Secure, 
      #                                   <tt>false</tt> if they are not enrolled and 
      #                                   <tt>nil</tt> if the service returns 'undefined'
      # <tt>signature_verfication</tt>  : a hash that needs to be POSTed to the ACS URL as PaReq
      # <tt>eci</tt>                    : the ECI code
      # <tt>xid</tt>                    : the XID code
      # <tt>cavv</tt>                   : the CAVV code
      # <tt>error_number</tt>           : the integer error code returned from MyGate if <tt>success</tt> is <tt>false</tt>
      # <tt>error_description</tt>      : a description of the error associated with <tt>error_number</tt>
      # 
      # ==== Usage
      # 
      # Primarily used to confirm that the authentication was processed, but attributes 
      # from this object is also used in the transaction request that follows it.
      class SecurityAuthResponse
        
        attr_reader :success, :pa_response_status, :signature_verification, 
                    :eci, :xid, :cavv, 
                    :error_number, :error_description
        
        alias :success? :success # to make it behave a bit more like Billing::Response
        
        def initialize(raw_xml)
          xml = REXML::Document.new raw_xml
          
          xml.elements.each('//authenticateReturn') do |node|
            key, value = node.text.split '||'
            case key
            when 'Result'
              @success = (value == '0')
            when 'PAResStatus'
              @pa_response_status = true  if value == 'Y'
              @pa_response_status = false if value == 'N'
              @pa_response_status = nil   if value == 'U'
            when 'SignatureVerification'
              @signature_verification = (value == 'Y')
            when 'ECI'
              @eci = value
            when 'XID'
              @xid = value
            when 'Cavv'
              @cavv = value
            when 'ErrorNo'
              @error_number = value.to_i
            when 'ErrorDesc'
              @error_description = value
            end
          end unless xml.root.nil?
        end
        
      end
      
    end
  end
end