module Braintree
  class Http # :nodoc:

    LINE_FEED = "\r\n"

    def initialize(config)
      @config = config
    end

    def delete(_path, query_params = {})
      path = _path + _build_query_string(query_params)
      response = _http_do Net::HTTP::Delete, path
      if response.code.to_i == 200 || response.code.to_i == 204
        true
      elsif response.code.to_i == 422
        Xml.hash_from_xml(_body(response))
      else
        Util.raise_exception_for_status_code(response.code)
      end
    end

    def get(_path, query_params = {})
      path = _path + _build_query_string(query_params)
      response = _http_do Net::HTTP::Get, path
      if response.code.to_i == 200 || response.code.to_i == 422
        Xml.hash_from_xml(_body(response))
      else
        Util.raise_exception_for_status_code(response.code)
      end
    end

    def post(path, params = nil, file = nil)
      body = params
      if !file
        body = _build_xml(params)
      end
      response = _http_do Net::HTTP::Post, path, body, file
      if response.code.to_i == 200 || response.code.to_i == 201 || response.code.to_i == 422
        Xml.hash_from_xml(_body(response))
      else
        Util.raise_exception_for_status_code(response.code)
      end
    end

    def put(path, params = nil)
      response = _http_do Net::HTTP::Put, path, _build_xml(params)
      if response.code.to_i == 200 || response.code.to_i == 201 || response.code.to_i == 422
        Xml.hash_from_xml(_body(response))
      else
        Util.raise_exception_for_status_code(response.code)
      end
    end

    def _build_xml(params)
      return "" if params.nil?
      Braintree::Xml.hash_to_xml params
    end

    def _build_query_string(params)
      if params.empty?
        ""
      else
        "?" + params.map do |x, y|
          raise(ArgumentError, "Nested hashes aren't supported in query parameters") if y.respond_to?(:to_hash)
          "#{x}=#{y}"
        end.join("&")
      end
    end

    def _setup_connection(server = @config.server, port = @config.port)
      if @config.proxy_address
        connection = Net::HTTP.new(
          server,
          port,
          @config.proxy_address,
          @config.proxy_port,
          @config.proxy_user,
          @config.proxy_pass
        )
      else
        connection = Net::HTTP.new(server, port)
      end
    end

    def _compose_headers(header_overrides = {})
      headers = {}
      headers["Accept"] = "application/xml"
      headers["User-Agent"] = @config.user_agent
      headers["Accept-Encoding"] = "gzip"
      headers["X-ApiVersion"] = @config.api_version
      headers["Content-Type"] = "application/xml"

      headers.merge(header_overrides)
    end

    def _http_do(http_verb, path, body = nil, file = nil, connection = nil, header_overrides = {})
      connection ||= _setup_connection

      connection.open_timeout = @config.http_open_timeout
      connection.read_timeout = @config.http_read_timeout
      if @config.ssl?
        connection.use_ssl = true
        connection.ssl_version = @config.ssl_version if @config.ssl_version
        connection.verify_mode = OpenSSL::SSL::VERIFY_PEER
        connection.ca_file = @config.ca_file
        connection.verify_callback = proc { |preverify_ok, ssl_context| _verify_ssl_certificate(preverify_ok, ssl_context) }
      end

      connection.start do |http|
        request = http_verb.new(path)
        _compose_headers(header_overrides).each { |header, value| request[header] = value }
        if @config.client_credentials?
          request.basic_auth @config.client_id, @config.client_secret
        elsif @config.access_token
          request["Authorization"] = "Bearer #{@config.access_token}"
        else
          request.basic_auth @config.public_key, @config.private_key
        end
        @config.logger.debug "[Braintree] [#{_current_time}] #{request.method} #{path}"
        if body
          if file
            boundary = DateTime.now.strftime("%Q")
            request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"

            form_params = []
            body.each do |k, v|
              form_params.push(_add_form_field(k, v))
            end
            form_params.push(_add_file_part("file", file))
            request.body = form_params.collect {|p| "--" + boundary + "#{LINE_FEED}" + p}.join("") + "--" + boundary + "--"
            @config.logger.debug _format_and_sanitize_body_for_log(_build_xml(body))
          else
            request.body = body
            @config.logger.debug _format_and_sanitize_body_for_log(body)
          end
        end
        response = http.request(request)
        @config.logger.info "[Braintree] [#{_current_time}] #{request.method} #{path} #{response.code}"
        @config.logger.debug "[Braintree] [#{_current_time}] #{response.code} #{response.message}"
        if @config.logger.level == Logger::DEBUG
          @config.logger.debug _format_and_sanitize_body_for_log(_body(response))
        end
        response
      end
    rescue OpenSSL::SSL::SSLError
      raise Braintree::SSLCertificateError
    end

    def _add_form_field(key, value)
      return "Content-Disposition: form-data; name=\"#{key}\"#{LINE_FEED}#{LINE_FEED}#{value}#{LINE_FEED}"
    end

    def _add_file_part(key, file)
      mime_type = _mime_type_for_file_name(file.path)
      return "Content-Disposition: form-data; name=\"#{key}\"; filename=\"#{file.path}\"#{LINE_FEED}" +
          "Content-Type: #{mime_type}#{LINE_FEED}#{LINE_FEED}#{file.read}#{LINE_FEED}"
    end

    def _mime_type_for_file_name(filename)
      file_extension = File.extname(filename).strip.downcase[1..-1]
      if file_extension == "jpeg" || file_extension == "jpg"
        return "image/jpeg"
      elsif file_extension == "png"
        return "image/png"
      elsif file_extension == "pdf"
        return "application/pdf"
      else
        return "application/octet-stream"
      end
    end

    def _body(response)
      content_encoding = response.header["Content-Encoding"]
      if content_encoding == "gzip"
        Zlib::GzipReader.new(StringIO.new(response.body)).read
      elsif content_encoding.nil?
        ""
      else
        raise UnexpectedError, "expected a gzipped response"
      end
    end

    def _current_time
      Time.now.utc.strftime("%d/%b/%Y %H:%M:%S %Z")
    end

    def _format_and_sanitize_body_for_log(input_xml)
      formatted_xml = input_xml.gsub(/^/, "[Braintree] ")
      formatted_xml = formatted_xml.gsub(/<number>(.{6}).+?(.{4})<\/number>/m, '<number>\1******\2</number>')
      formatted_xml = formatted_xml.gsub(/<cvv>.+?<\/cvv>/m, '<cvv>***</cvv>')
      formatted_xml
    end

    def _verify_ssl_certificate(preverify_ok, ssl_context)
      if preverify_ok != true || ssl_context.error != 0
        err_msg = "SSL Verification failed -- Preverify: #{preverify_ok}, Error: #{ssl_context.error_string} (#{ssl_context.error})"
        @config.logger.error err_msg
        false
      else
        true
      end
    end
  end
end

