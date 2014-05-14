module AuthorizeNet
  class XmlTransaction

    # Fields to convert to/from booleans.
    @@boolean_fields = []

    # Fields to convert to/from BigDecimal.
    @@decimal_fields = []

    # Fields to convert to/from Date.
    @@date_fields = []

    # Fields to convert to/from DateTime.
    @@datetime_fields = []

    # The class to wrap our response in.
    @response_class = AuthorizeNet::XmlResponse

    # The default options for the constructor.
    @@option_defaults = {
        :gateway => :production,
        :verify_ssl => false,
        :reference_id => nil
    }

    # Checks if the transaction has been configured for the sandbox or not. Return FALSE if the
    # transaction is running against the production, TRUE otherwise.
    def test?
      @gateway != Gateway::LIVE
    end

    # Checks to see if the transaction has a response (meaning it has been submitted to the gateway).
    # Returns TRUE if a response is present, FALSE otherwise.
    def has_response?
      !@response.nil?
    end

    # Retrieve the response object (or Nil if transaction hasn't been sent to the gateway).
    def response
      @response
    end

    # Submits the transaction to the gateway for processing. Returns a response object. If the transaction
    # has already been run, it will return nil.
    def run
      make_request
    end

    # Returns a deep-copy of the XML object sent to the payment gateway. Or nil if there was no XML payload.
    def xml
      @xml
    end

    #:enddoc:
    protected

    # Takes a list of nodes (a Hash is a node, and Array is a list) and returns True if any nodes
    # would be built by build_nodes. False if no new nodes would be generated.
    def has_content(nodeList, data)
      nodeList.each do |node|
        nodeName = (node.keys.reject {|k| nodeName.to_s[0..0] == '_' }).first
        multivalue = node[:_multivalue]
        conditional = node[:_conditional]
        value = node[nodeName]
        unless conditional.nil?
          value = self.send(conditional, nodeName)
        end
        case value
          when Array
            if multivalue.nil?
              if has_content(value, data)
                return true
              end
            else
              data[multivalue].each do |v|
                if has_content(value, v)
                  return true
                end
              end
            end
          when Symbol
            converted = convert_field(value, data[value])
            return true unless converted.nil?
          else
            return true
        end
      end
      false
    end

    # Takes a list of nodes (a Hash is a node, and Array is a list) and recursively builds the XML by pulling
    # values as needed from data.
    def build_nodes(builder, nodeList, data)
      nodeList.each do |node|
        nodeName = (node.keys.reject {|k| k.to_s[0..0] == '_' }).first
        multivalue = node[:_multivalue]
        conditional = node[:_conditional]
        value = node[nodeName]
        unless conditional.nil?
          value = self.send(conditional, nodeName)
        end
        case value
          when Array # node containing other nodes
            if multivalue.nil?
              proc = Proc.new { build_nodes(builder, value, data) }
              builder.send(nodeName, &proc) if has_content(value, data)
            else
              data[multivalue].to_a.each do |v|
                proc = Proc.new { build_nodes(builder, value, v) }
                builder.send(nodeName, &proc) if has_content(value, v)
              end
            end
          when Symbol # node containing actual data
            if data[value].kind_of?(Array)
              data[value].each do |v|
                converted = convert_field(value, v)
                builder.send(nodeName, converted) unless converted.nil?
              end
            else
              converted = convert_field(value, data[value])
              builder.send(nodeName, converted) unless converted.nil?
            end
          else
            builder.send(nodeName, value)
        end
      end
    end

    def convert_field(field, value)
      if @@boolean_fields.include?(field) and !value.nil?
        return boolean_to_value(value)
      elsif @@decimal_fields.include?(field) and !value.nil?
        return decimal_to_value(value)
      elsif @@date_fields.include?(field) and !value.nil?
        return date_to_value(value)
      elsif @@datetime_fields.include?(field) and !value.nil?
        return datetime_to_value(value)
      elsif field == :extra_options
        # handle converting extra options
        options = []
        unless value.nil?
          value.each_pair{|k,v| options <<= self.to_param(k, v)}
        end
        unless @custom_fields.nil?
          # special sort to maintain compatibility with AIM custom field ordering
          # FIXME - This should be DRY'd up.
          custom_field_keys = @custom_fields.keys.collect(&:to_s).sort.collect(&:to_sym)
          for key in custom_field_keys
            options <<= self.to_param(key, @custom_fields[key.to_sym], '')
          end
        end

        if options.length > 0
          return options.join('&')
        else
          return nil
        end
      elsif field == :exp_date
        # convert MMYY expiration dates into the XML equivalent
        unless value.nil?
          begin
            return value.to_s.downcase == 'xxxx' ? 'XXXX' : Date.strptime(value.to_s, '%m%y').strftime('%Y-%m')
          rescue
            # If we didn't get the exp_date in MMYY format, try our best to convert it
            return Date.parse(value.to_s).strftime('%Y-%m')
          end
        end
      end

      value
    end

    # An internal method that builds the POST body, submits it to the gateway, and constructs a Response object with the response.
    def make_request
      if has_response?
        return nil
      end

      fields = @fields

      builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |x|
        x.send(@type.to_sym, :xmlns => XML_NAMESPACE) {
          x.merchantAuthentication {
            x.name @api_login_id
            x.transactionKey @api_transaction_key
          }
          build_nodes(x, self.class.const_get(:FIELDS)[@type], fields)
        }
      end
      @xml = builder.to_xml

      url = URI.parse(@gateway)

      request = Net::HTTP::Post.new(url.path)
      request.content_type = 'text/xml'
      request.body = @xml
      connection = Net::HTTP.new(url.host, url.port)
      connection.use_ssl = true
      if @verify_ssl
        connection.verify_mode = OpenSSL::SSL::VERIFY_PEER
      else
        connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      # Use our Class's @response_class variable to find the Response class we are supposed to use.
      begin
        @response = self.class.instance_variable_get(:@response_class).new((connection.start {|http| http.request(request)}), self)
      rescue
        @response = self.class.instance_variable_get(:@response_class).new($!, self)
      end
    end

  end
end