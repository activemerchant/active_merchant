warn 'mechanize/cookie_jar will be deprecated.  Please migrate to the http-cookie APIs.' if $VERBOSE

require 'http/cookie_jar'
require 'http/cookie_jar/yaml_saver'
require 'mechanize/cookie'

class Mechanize
  module CookieJarIMethods
    include CookieDeprecated

    def add(arg1, arg2 = nil)
      if arg2
        __deprecated__ 'add and origin='
        super arg2.dup.tap { |ncookie|
          begin
            ncookie.origin = arg1
          rescue
            return nil
          end
        }
      else
        super arg1
      end
    end

    # See HTTP::CookieJar#add.
    def add!(cookie)
      __deprecated__ :add
      cookie.domain.nil? and raise NoMethodError, 'raised for compatibility'
      @store.add(cookie)
      self
    end

    # See HTTP::CookieJar#save.
    def save_as(filename, *options)
      __deprecated__ :save
      save(filename, *options)
    end

    # See HTTP::CookieJar#clear.
    def clear!
      __deprecated__ :clear
      clear
    end

    # See HTTP::CookieJar#store.
    def jar
      __deprecated__ :store
      @store.instance_variable_get(:@jar)
    end

    # See HTTP::CookieJar#load.
    def load_cookiestxt(io)
      __deprecated__ :load
      load(io, :cookiestxt)
    end

    # See HTTP::CookieJar#save.
    def dump_cookiestxt(io)
      __deprecated__ :save
      save(io, :cookiestxt)
    end
  end

  class CookieJar < ::HTTP::CookieJar
    def save(output, *options)
      output.respond_to?(:write) or
        return open(output, 'w') { |io| save(io, *options) }

      opthash = {
        :format => :yaml,
        :session => false,
      }
      case options.size
      when 0
      when 1
        case options = options.first
        when Symbol
          opthash[:format] = options
        else
          opthash.update(options) if options
        end
      when 2
        opthash[:format], options = options
        opthash.update(options) if options
      else
        raise ArgumentError, 'wrong number of arguments (%d for 1-3)' % (1 + options.size)
      end

      return super(output, opthash) if opthash[:format] != :yaml

      session = opthash[:session]
      nstore = HashStore.new

      each { |cookie|
        next if !session && cookie.session?

        if cookie.max_age
          cookie = cookie.dup
          cookie.expires = cookie.expires # convert max_age to expires
        end
        nstore.add(cookie)
      }

      yaml = YAML.dump(nstore.instance_variable_get(:@jar))

      # a gross hack
      yaml.gsub!(%r{^(    [^ ].*: !ruby/object:)HTTP::Cookie$}) {
        $1 + 'Mechanize::Cookie'
      }
      yaml.gsub!(%r{^(      expires: )(?:|!!null|(.+?)) *$}) {
        $1 + ($2 ? Time.parse($2).httpdate : '')
      }

      output.write yaml

      self
    end

    def load(input, *options)
      input.respond_to?(:write) or
        return open(input, 'r') { |io| load(io, *options) }

      opthash = {
        :format => :yaml,
        :session => false,
      }
      case options.size
      when 0
      when 1
        case options = options.first
        when Symbol
          opthash[:format] = options
        else
          if hash = Hash.try_convert(options)
            opthash.update(hash)
          end
        end
      when 2
        opthash[:format], options = options
        if hash = Hash.try_convert(options)
          opthash.update(hash)
        end
      else
        raise ArgumentError, 'wrong number of arguments (%d for 1-3)' % (1 + options.size)
      end

      return super(input, opthash) if opthash[:format] != :yaml

      begin
        data = YAML.load(input)
      rescue ArgumentError
        @logger.warn "unloadable YAML cookie data discarded" if @logger
        return self
      end

      case data
      when Array
        # Forward compatibility
        data.each { |cookie|
          add(cookie)
        }
      when Hash
        data.each { |domain, paths|
          paths.each { |path, names|
            names.each { |cookie_name, cookie|
              add(cookie)
            }
          }
        }
      else
        @logger.warn "incompatible YAML cookie data discarded" if @logger
        return self
      end
    end
  end

  # Compatibility for Ruby 1.8/1.9
  unless ::HTTP::CookieJar.respond_to?(:prepend, true)
    require 'mechanize/prependable'

    class ::HTTP::CookieJar
      extend Prependable
    end
  end

  class ::HTTP::CookieJar
    prepend CookieJarIMethods
  end
end
