module CecabankCommon
  #### CECA's MAGIC NUMBERS
  CECA_ENCRIPTION = 'SHA2'
  CECA_CURRENCIES_DICTIONARY = { 'EUR' => 978, 'USD' => 840, 'GBP' => 826 }

  def self.included(base)
    base.supported_countries = ['ES']
    base.supported_cardtypes = %i[visa master american_express]
    base.homepage_url = 'http://www.ceca.es/es/'
    base.display_name = 'Cecabank'
    base.default_currency = 'EUR'
    base.money_format = :cents
  end

  # Creates a new CecabankGateway
  #
  # The gateway requires four values for connection to be passed
  # in the +options+ hash.
  #
  # ==== Options
  #
  # * <tt>:merchant_id</tt>  -- Cecabank's merchant_id (REQUIRED)
  # * <tt>:acquirer_bin</tt> -- Cecabank's acquirer_bin (REQUIRED)
  # * <tt>:terminal_id</tt>  -- Cecabank's terminal_id (REQUIRED)
  # * <tt>:cypher_key</tt>   -- Cecabank's cypher key (REQUIRED)
  # * <tt>:test</tt>         -- +true+ or +false+. If true, perform transactions against the test server.
  #   Otherwise, perform transactions against the production server.
  def initialize(options = {})
    requires!(options, :merchant_id, :acquirer_bin, :terminal_id, :cypher_key)
    super
  end

  def supports_scrubbing?
    true
  end
end
