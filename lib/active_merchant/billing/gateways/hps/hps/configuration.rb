module Hps
  module Configuration

    VALID_CONFIG_KEYS = [ :service_uri, :user_name, :password, :developer_id, :version_number, :license_id, :device_id, :site_id, :site_trace, :secret_api_key ].freeze    

    attr_accessor *VALID_CONFIG_KEYS

    def configure
      yield self
    end
    
    def options
      Hash[ * VALID_CONFIG_KEYS.map { |key| [key, send(key)] }.flatten ]
    end
    
  end
end