module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module MyGate #:nodoc:
      
      # The MyGateGateway::Response class contains the result of an actual transaction response. 
      # An object of this class is returned from MyGateGateway#authorize, MyGateGateway#capture 
      # and MyGateGateway#purchase.
      # 
      # This class handles the XML parsing for the API request.
      # 
      # ==== Properties
      # 
      # <tt>success</tt>            : <tt>true</tt> if the service returned a Result of 0, <tt>false</tt> otherwise
      # <tt>message</tt>            : a <tt>String</tt> message indicating the error or success message
      # <tt>transaction_index</tt>  : the transaction index that MyGate returned as an uppercase <tt>String</tt>
      # <tt>authorization</tt>      : an <tt>Array</tt> containing the AuthorisationIDs reutrned by the gateway
      # <tt>xml</tt>                : the <tt>REXML::Document</tt> parsed from the response available for debugging
      class Response < Billing::Response
        
        # The message that will be retrieved from the <tt>message</tt> attribute when successful.
        SUCCESS = 'Transaction processed successfully'
        
        attr_reader :xml, :transaction_index
        
        def initialize(raw_xml, options = {})
          @xml = REXML::Document.new(raw_xml)
          
          # Behave consistent with Billing::Response where possible
          @test = options[:test] || false
          @authorization = []
          
          # Parse both responses with the same class, since they are so similar
          @xml.elements.each('//fProcessAndSettleReturn | //fProcessReturn') do |node|
            key, *values = node.text.split '||'
            case key
            when 'Result'
              @success = (values[0].to_i >= 0)
              @message = SUCCESS if @success
            when 'TransactionIndex'
              @transaction_index = values[0].upcase
            when 'AuthorisationID'
              @authorization << values[0]
            when 'Error'
              @message = values.last
            when 'Warning'
              @message = "Warning: #{values.last}"
            end
          end unless xml.root.nil?
          
        end
        
      end
      
    end
  end
end
