require 'active_support/core_ext/hash/conversions'

module Hps
	class HpsService

		attr_accessor :exception_mapper
    
    attr_accessor *Configuration::VALID_CONFIG_KEYS

		def initialize(options={})
      
      merged_options = Hps.options.merge(options)
      
      Configuration::VALID_CONFIG_KEYS.each do |key|
        send("#{key}=", merged_options[key])
      end
       
			@exception_mapper = Hps::ExceptionMapper.new
		end

		#protected

		def doTransaction(transaction)

			if configuration_invalid
      	raise @exception_mapper.map_sdk_exception(SdkCodes.invalid_transaction_id)
			end
      
      xml = Builder::XmlMarkup.new
      xml.instruct!(:xml, :encoding => "UTF-8")      
      xml.SOAP :Envelope, {
        'xmlns:SOAP' => 'http://schemas.xmlsoap.org/soap/envelope/', 
        'xmlns:hps' => 'http://Hps.Exchange.PosGateway' } do          
        xml.SOAP :Body do
          xml.hps :PosRequest do
            xml.hps 'Ver1.0'.to_sym do
              xml.hps :Header do
                if self.secret_api_key
                  self.service_uri = gateway_url_for_key self.secret_api_key                          
                  xml.hps :SecretAPIKey, self.secret_api_key
                else                  
            			xml.hps :UserName, self.user_name
            			xml.hps :Password, self.password                    
            			xml.hps :DeviceId, self.device_id
            			xml.hps :LicenseId, self.license_id
            			xml.hps :SiteId, self.site_id
                end                   
          			xml.hps :DeveloperID, self.developer_id if self.developer_id
          			xml.hps :VersionNbr, self.version_number if self.version_number
          			xml.hps :SiteTrace, self.site_trace if self.site_trace                  
              end
              
              xml << transaction
              
            end              
          end            
        end        
      end   
      
			begin
    
        uri = URI.parse(self.service_uri)
        http = Net::HTTP.new uri.host, uri.port
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        data = xml.target!        

        response = http.post(uri.path, data, 'Content-type' => 'text/xml')

        # NOTE: If the HTTP request was successful
        if response.is_a? Net::HTTPOK
          
          # NOTE: Convert XML to a Hash
          soap_hash = Hash.from_xml(response.body)
          # NOTE: Peel away the layers and return only the PosRespose
          soap_hash["Envelope"]["Body"]["PosResponse"]["Ver1.0"]
          
        else
  				raise @exception_mapper.map_sdk_exception(SdkCodes.unable_to_process_transaction)
        end

			rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
       Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
				raise @exception_mapper.map_sdk_exception(SdkCodes.unable_to_process_transaction, e)
			end

		end
    
    def gateway_url_for_key(api_key)
      
      gateway_url = "https://posgateway.secureexchange.net/Hps.Exchange.PosGateway/PosGatewayService.asmx?wsdl"
      
      if api_key.include? "_uat_"

        gateway_url = "https://posgateway.uat.secureexchange.net/Hps.Exchange.PosGateway/PosGatewayService.asmx?wsdl"

      elsif api_key.include? "_cert_"

        gateway_url = "https://posgateway.cert.secureexchange.net/Hps.Exchange.PosGateway/PosGatewayService.asmx?wsdl" 
      end      
      
      gateway_url
    end

		def hydrate_transaction_header(header)
			result = HpsTransactionHeader.new
			result.gateway_response_code = header["GatewayRspCode"]
			result.gateway_response_message = header["GatewayRspMsg"]
			result.response_dt = header["RspDT"]
			result.client_txn_id = header["GatewayTxnId"]
			result
		end
    
    private
    
		def configuration_invalid
      self.secret_api_key.nil? and (
  			self.service_uri.nil? or
  			self.user_name.nil? or
  			self.password.nil? or
  			self.license_id.nil? or 
  			self.device_id.nil? or 
  			self.site_id.nil?
      )
		end

	end
end