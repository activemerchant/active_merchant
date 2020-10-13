# coding: BINARY

require 'strscan'

##
# Parses the WWW-Authenticate HTTP header into separate challenges.

class Mechanize::HTTP::WWWAuthenticateParser

  attr_accessor :scanner # :nodoc:

  ##
  # Creates a new header parser for WWW-Authenticate headers

  def initialize
    @scanner = nil
  end

  ##
  # Parsers the header.  Returns an Array of challenges as strings

  def parse www_authenticate
    challenges = []
    @scanner = StringScanner.new www_authenticate

    while true do
      break if @scanner.eos?
      start = @scanner.pos
      challenge = Mechanize::HTTP::AuthChallenge.new

      scheme = auth_scheme

      if scheme == 'Negotiate'
        scan_comma_spaces
      end

      break unless scheme
      challenge.scheme = scheme

      space = spaces

      if scheme == 'NTLM' then
        if space then
          challenge.params = @scanner.scan(/.*/)
        end

        challenge.raw = www_authenticate[start, @scanner.pos]
        challenges << challenge
        next
      else
        scheme.capitalize!
      end

      next unless space

      params = {}

      while true do
        pos = @scanner.pos
        name, value = auth_param

        name.downcase! if name =~ /^realm$/i

        unless name then
          challenge.params = params
          challenges << challenge

          if @scanner.eos? then
            challenge.raw = www_authenticate[start, @scanner.pos]
            break
          end

          @scanner.pos = pos # rewind
          challenge.raw = www_authenticate[start, @scanner.pos].sub(/(,+)? *$/, '')
          challenge = nil # a token should be next, new challenge
          break
        else
          params[name] = value
        end

        spaces

        @scanner.scan(/(, *)+/)
      end
    end

    challenges
  end

  ##
  #   1*SP
  #
  # Parses spaces

  def spaces
    @scanner.scan(/ +/)
  end

  ##
  # scans a comma followed by spaces
  # needed for Negotiation, NTLM
  #

  def scan_comma_spaces
    @scanner.scan(/, +/)
  end

  ##
  #   token = 1*<any CHAR except CTLs or separators>
  #
  # Parses a token

  def token
    @scanner.scan(/[^\000-\037\177()<>@,;:\\"\/\[\]?={} ]+/)
  end

  ##
  #   auth-scheme = token
  #
  # Parses an auth scheme (a token)

  alias auth_scheme token

  ##
  #   auth-param = token "=" ( token | quoted-string )
  #
  # Parses an auth parameter

  def auth_param
    return nil unless name = token
    return nil unless @scanner.scan(/ *= */)

    value = if @scanner.peek(1) == '"' then
              quoted_string
            else
              token
            end

    return nil unless value

    return name, value
  end

  ##
  #   quoted-string = ( <"> *(qdtext | quoted-pair ) <"> )
  #   qdtext        = <any TEXT except <">>
  #   quoted-pair   = "\" CHAR
  #
  # For TEXT, the rules of RFC 2047 are ignored.

  def quoted_string
    return nil unless @scanner.scan(/"/)

    text = ''

    while true do
      chunk = @scanner.scan(/[\r\n \t\041\043-\176\200-\377]+/) # not "

      if chunk then
        text << chunk

        text << @scanner.get_byte if
          chunk.end_with? '\\' and '"' == @scanner.peek(1)
      else
        if '"' == @scanner.peek(1) then
          @scanner.get_byte
          break
        else
          return nil
        end
      end
    end

    text
  end

end

