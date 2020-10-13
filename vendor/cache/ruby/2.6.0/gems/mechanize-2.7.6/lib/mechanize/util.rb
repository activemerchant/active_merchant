require 'cgi'
require 'nkf'

class Mechanize::Util
  # default mime type data for Page::Image#mime_type.
  # You can use another Apache-compatible mimetab.
  #   mimetab = WEBrick::HTTPUtils.load_mime_types('/etc/mime.types')
  #   Mechanize::Util::DefaultMimeTypes.replace(mimetab)
  DefaultMimeTypes = WEBrick::HTTPUtils::DefaultMimeTypes

  class << self
    # Builds a query string from a given enumerable object
    # +parameters+.  This method uses Mechanize::Util.each_parameter
    # as preprocessor, which see.
    def build_query_string(parameters, enc = nil)
      each_parameter(parameters).inject(nil) { |s, (k, v)|
        # WEBrick::HTTP.escape* has some problems about m17n on ruby-1.9.*.
        (s.nil? ? '' : s << '&') << [CGI.escape(k.to_s), CGI.escape(v.to_s)].join('=')
      } || ''
    end

    # Parses an enumerable object +parameters+ and iterates over the
    # key-value pairs it contains.
    #
    # +parameters+ may be a hash, or any enumerable object which
    # iterates over [key, value] pairs, typically an array of arrays.
    #
    # If a key is paired with an array-like object, the pair is
    # expanded into multiple occurrences of the key, one for each
    # element of the array.  e.g. { a: [1, 2] } => [:a, 1], [:a, 2]
    #
    # If a key is paired with a hash-like object, the pair is expanded
    # into hash-like multiple pairs, one for each pair of the hash.
    # e.g. { a: { x: 1, y: 2 } } => ['a[x]', 1], ['a[y]', 2]
    #
    # An array-like value is allowed to be specified as hash value.
    # e.g. { a: { q: [1, 2] } } => ['a[q]', 1], ['a[q]', 2]
    #
    # For a non-array-like, non-hash-like value, the key-value pair is
    # yielded as is.
    def each_parameter(parameters, &block)
      return to_enum(__method__, parameters) if block.nil?

      parameters.each { |key, value|
        each_parameter_1(key, value, &block)
      }
    end

    private

    def each_parameter_1(key, value, &block)
      return if key.nil?

      case
      when s = String.try_convert(value)
        yield [key, s]
      when a = Array.try_convert(value)
        a.each { |avalue|
          yield [key, avalue]
        }
      when h = Hash.try_convert(value)
        h.each { |hkey, hvalue|
          each_parameter_1('%s[%s]' % [key, hkey], hvalue, &block)
        }
      else
        yield [key, value]
      end
    end
  end

  # Converts string +s+ from +code+ to UTF-8.
  def self.from_native_charset(s, code, ignore_encoding_error = false, log = nil)
    return s unless s && code
    return s unless Mechanize.html_parser == Nokogiri::HTML

    begin
      s.encode(code)
    rescue EncodingError => ex
      log.debug("from_native_charset: #{ex.class}: form encoding: #{code.inspect} string: #{s}") if log
      if ignore_encoding_error
        s
      else
        raise
      end
    end
  end

  def self.html_unescape(s)
    return s unless s
    s.gsub(/&(\w+|#[0-9]+);/) { |match|
      number = case match
               when /&(\w+);/
                 Mechanize.html_parser::NamedCharacters[$1]
               when /&#([0-9]+);/
                 $1.to_i
               end

      number ? ([number].pack('U') rescue match) : match
    }
  end

  case NKF::BINARY
  when Encoding
    def self.guess_encoding(src)
      # NKF.guess of JRuby may return nil
      NKF.guess(src) || Encoding::US_ASCII
    end
  else
    # Old NKF from 1.8, still bundled with Rubinius
    NKF_ENCODING_MAP = {
      NKF::UNKNOWN => Encoding::US_ASCII,
      NKF::BINARY  => Encoding::ASCII_8BIT,
      NKF::ASCII   => Encoding::US_ASCII,
      NKF::JIS     => Encoding::ISO_2022_JP,
      NKF::EUC     => Encoding::EUC_JP,
      NKF::SJIS    => Encoding::Shift_JIS,
      NKF::UTF8    => Encoding::UTF_8,
      NKF::UTF16   => Encoding::UTF_16BE,
      NKF::UTF32   => Encoding::UTF_32BE,
    }

    def self.guess_encoding(src)
      NKF_ENCODING_MAP[NKF.guess(src)]
    end
  end

  def self.detect_charset(src)
    if src
      guess_encoding(src).name.upcase
    else
      Encoding::ISO8859_1.name
    end
  end

  def self.uri_escape str, unsafe = nil
    @parser ||= begin
                  URI::Parser.new
                rescue NameError
                  URI
                end

    if URI == @parser then
      unsafe ||= URI::UNSAFE
    else
      unsafe ||= @parser.regexp[:UNSAFE]
    end

    @parser.escape str, unsafe
  end

  def self.uri_unescape str
    @parser ||= begin
                  URI::Parser.new
                rescue NameError
                  URI
                end

    @parser.unescape str
  end

end
