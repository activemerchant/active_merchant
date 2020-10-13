class Mechanize::HTTP

  AuthChallenge = Struct.new :scheme, :params, :raw

  ##
  # A parsed WWW-Authenticate header

  class AuthChallenge

    ##
    # :attr_accessor: scheme
    #
    # The authentication scheme

    ##
    # :attr_accessor: params
    #
    # The authentication parameters

    ##
    # :method: initialize
    #
    # :call-seq:
    #   initialize(scheme = nil, params = nil)
    #
    # Creates a new AuthChallenge header with the given scheme and parameters

    ##
    # Retrieves +param+ from the params list

    def [] param
      params[param]
    end

    ##
    # Constructs an AuthRealm for this challenge

    def realm uri
      case scheme
      when 'Basic' then
        raise ArgumentError, "provide uri for Basic authentication" unless uri
        Mechanize::HTTP::AuthRealm.new scheme, uri + '/', self['realm']
      when 'Digest' then
        Mechanize::HTTP::AuthRealm.new scheme, uri + '/', self['realm']
      else
        raise Mechanize::Error, "unknown HTTP authentication scheme #{scheme}"
      end
    end

    ##
    # The name of the realm for this challenge

    def realm_name
      params['realm'] if Hash === params # NTLM has a string for params
    end

    ##
    # The raw authentication challenge

    alias to_s raw

  end

end

