module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module MyGate #:nodoc:
      
      # An object of this class is returned from MyGateGateway#security_pre_auth.
      # This class handles the XML parsing for the API request.
      # 
      # ==== Properties
      # 
      # <tt>success</tt>            : <tt>true</tt> if the service returned a Result of 0
      # <tt>enrolled</tt>           : <tt>true</tt> if the cardholder is enrolled for 3D-Secure, 
      #                               <tt>false</tt> if they are not enrolled and 
      #                               <tt>nil</tt> if the service returns 'undefined'
      # <tt>eci</tt>                : the ECI code (only present if thy are not enrolled)
      # <tt>acs_url</tt>            : the URL to which the user should be redirected with a POST
      # <tt>transaction_index</tt>  : the transaction index that needs to be POSTed to the ACS URL as TransactionIndex
      # <tt>pa_request_message</tt> : a hash that needs to be POSTed to the ACS URL as PaReq
      # <tt>error_number</tt>       : The integer error code returned from MyGate if <tt>success</tt> is <tt>false</tt>
      # <tt>error_description</tt>  : A description of the error associated with <tt>error_number</tt>
      # 
      # ==== Usage
      # 
      # Once this object is obtained by calling MyGateGateway#security_pre_auth
      # the user should be redirected to the <tt>acs_url</tt> with an HTTP POST
      # containing the following paramters as per {the documentation}[http://mygate.co.za/images/PDFs/myenterprise_userguide.pdf]:
      # 
      # <tt>PaReq</tt> -- The <tt>pa_request_message</tt> received.
      # <tt>TermUrl</tt> -- The URL where you want the user to be redirected to after authenticating.
      #                     Configure a controller to receive the POST at this URL and pass the 
      #                     params back into MyGateGateway#process_acs.
      # <tt>TransactionIndex</tt> -- The <tt>transaction_index</tt> received.
      class SecurityPreAuthResponse
        
        attr_reader :success, :enrolled, :transaction_index, :acs_url, :pa_request_message, :eci,
                    :error_number, :error_description
        
        alias :success? :success # to make it behave a bit more like Billing::Response
        
        def initialize(raw_xml)
          xml = REXML::Document.new raw_xml
          
          xml.elements.each('//lookupReturn') do |node|
            key, value = node.text.split '||'
            case key
            when 'Result'
              @success = (value == '0')
            when 'Enrolled'
              @enrolled = true  if value == 'Y'
              @enrolled = false if value == 'N'
              @enrolled = nil   if value == 'U'
            when 'TransactionIndex'
              @transaction_index = value
            when 'ACSUrl'
              @acs_url = value
            when 'PAReqMsg'
              @pa_request_message = value
            when 'ECI'
              @eci = value
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