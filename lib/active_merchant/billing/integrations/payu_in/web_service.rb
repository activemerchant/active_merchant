require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayuIn

        # PayU.in provides web services to help you with reconciliation of your transactions in real time.
        class WebService < Hash

          # Add helper method to make api calls using ssl_post, ssl_get
          include PostsData

          # Whether the invoice is success or not
          # Invoice id is required when multiple invoices are queried at once
          def complete?( invoice_id = nil )
            status( invoice_id ).to_s.downcase == 'success'
          end

          # Whether the invoice is pending confirmation
          # Invoice id is required when multiple invoices are queried at once
          def pending?( invoice_id = nil )
            status( invoice_id ).to_s.downcase == 'pending'
          end

          # Returns the payment status of the invoice
          # invoice_id is required if multiple invoices are queried at once
          def status( invoice_id = nil )
            ( invoice_id ? self[ invoice_id.to_s ] : self )[ 'status']
          end

          # Returns whether the order amount and order discount matches
          # generally in third party shopping carts order discount is handle by the application
          # and should generally by 0.0
          def amount_ok?( order_amount, order_discount = BigDecimal.new( '0.0' ), invoice_id = nil )
            hash = ( invoice_id ? self[ invoice_id.to_s ] : self )
            ( BigDecimal.new( hash[ 'amt' ] ) == order_amount ) && ( BigDecimal.new( hash[ 'disc' ] ) == order_discount )
          end

          # Returns whether the nett amount after reducing the discounts
          def nett_amount( invoice_id = nil )
            hash = ( invoice_id ? self[ invoice_id.to_s ] : self )
            BigDecimal.new( hash[ 'amt' ] ) - BigDecimal.new( hash[ 'disc' ] )
          end

          # Returns the PayU.in transaction if for the invocie
          # invoice_id is required if multiple invoices are queried at once
          def transaction_id( invoice_id = nil )
            ( invoice_id ? self[ invoice_id.to_s ] : self )[ 'mihpayid']
          end

          # Makes verify payment API call to PayU.in web service
          # Params - any number of invoice ids ( provided by the merchant )
          def self.verify_payment( *invoice_ids )
            invoice_string = invoice_ids.join( '|' )
            checksum = PayuIn.checksum( 'verify_payment', invoice_string )
            new.web_service_call( :command => 'verify_payment', :var1 => invoice_string, :hash => checksum, :key => PayuIn.merchant_id )
          end

          # Makes check payment API call to PayU.in web service
          # Params - PayU.in transaction id
          def self.check_payment( payu_id )
            checksum = PayuIn.checksum( 'check_payment', payu_id )
            new.web_service_call( :command => 'check_payment', :var1 => payu_id, :hash => checksum, :key => PayuIn.merchant_id )
          end

          # Utility method which makes the web service call and
          # parse the response into WebService object
          def web_service_call( params = {} )
            payload_hash = ActiveMerchant::PostData.new
            payload_hash.merge!( params )
            payload = payload_hash.to_post_data
            response = PHP.unserialize(
              ssl_post(
                PayuIn.web_service_url, payload,
                'Content-Length' => "#{payload.size}",
                'User-Agent'     => "Active Merchant -- http://activemerchant.org"
              )
            )
            merge!( response["transaction_details"] && response["transaction_details"].size == 1 ? response["transaction_details"].values.first : ( response["transaction_details"] || { :status => response['msg'] } ) )
          end

        end

        module PHP
          def PHP.serialize(var, assoc = false) # {{{
            s = ''
            case var
            when Array
              s << "a:#{var.size}:{"
              if assoc and var.first.is_a?(Array) and var.first.size == 2
                var.each { |k,v|
                  s << PHP.serialize(k, assoc) << PHP.serialize(v, assoc)
                }
              else
                var.each_with_index { |v,i|
                  s << "i:#{i};#{PHP.serialize(v, assoc)}"
                }
              end

              s << '}'

            when Hash
              s << "a:#{var.size}:{"
              var.each do |k,v|
                s << "#{PHP.serialize(k, assoc)}#{PHP.serialize(v, assoc)}"
              end
              s << '}'

            when Struct
              # encode as Object with same name
              s << "O:#{var.class.to_s.length}:\"#{var.class.to_s.downcase}\":#{var.members.length}:{"
              var.members.each do |member|
                s << "#{PHP.serialize(member, assoc)}#{PHP.serialize(var[member], assoc)}"
              end
              s << '}'

            when String, Symbol
              s << "s:#{var.to_s.bytesize}:\"#{var.to_s}\";"

            when Fixnum # PHP doesn't have bignums
              s << "i:#{var};"

            when Float
              s << "d:#{var};"

            when NilClass
              s << 'N;'

            when FalseClass, TrueClass
              s << "b:#{var ? 1 :0};"

            else
              if var.respond_to?(:to_assoc)
                v = var.to_assoc
                # encode as Object with same name
                s << "O:#{var.class.to_s.length}:\"#{var.class.to_s.downcase}\":#{v.length}:{"
                v.each do |k,v|
                  s << "#{PHP.serialize(k.to_s, assoc)}#{PHP.serialize(v, assoc)}"
                end
                s << '}'
              else
                raise TypeError, "Unable to serialize type #{var.class}"
              end
            end

            s
          end # }}}

          # string = PHP.serialize_session(mixed var[, bool assoc])
          #
          # Like PHP.serialize, but only accepts a Hash or associative Array as the root
          # type.  The results are returned in PHP session format.
          def PHP.serialize_session(var, assoc = false) # {{{
            s = ''
            case var
            when Hash
              var.each do |key,value|
                if key.to_s =~ /\|/
                  raise IndexError, "Top level names may not contain pipes"
                end
                s << "#{key}|#{PHP.serialize(value, assoc)}"
              end
            when Array
              var.each do |x|
                case x
                when Array
                  if x.size == 2
                    s << "#{x[0]}|#{PHP.serialize(x[1])}"
                  else
                    raise TypeError, "Array is not associative"
                  end
                end
              end
            else
              raise TypeError, "Unable to serialize sessions with top level types other than Hash and associative Array"
            end
            s
          end # }}}

          def PHP.unserialize(string, classmap = nil, assoc = false) # {{{
            if classmap == true or classmap == false
              assoc = classmap
              classmap = {}
            end
            classmap ||= {}

            require 'stringio'
            string = StringIO.new(string)
            def string.read_until(char)
              val = ''
              while (c = self.read(1)) != char
                val << c
              end
              val
            end

            if string.string =~ /^(\w+)\|/ # session_name|serialized_data
              ret = Hash.new
              loop do
                if string.string[string.pos, 32] =~ /^(\w+)\|/
                  string.pos += $&.size
                  ret[$1] = PHP.do_unserialize(string, classmap, assoc)
                else
                  break
                end
              end
              ret
            else
              PHP.do_unserialize(string, classmap, assoc)
            end
          end

          private
          def PHP.do_unserialize(string, classmap, assoc)
            val = nil
            # determine a type
            type = string.read(2)[0,1]
            case type
            when 'a' # associative array, a:length:{[index][value]...}
              count = string.read_until('{').to_i
              val = vals = Array.new
              count.times do |i|
                vals << [do_unserialize(string, classmap, assoc), do_unserialize(string, classmap, assoc)]
              end
              string.read(1) # skip the ending }

              # now, we have an associative array, let's clean it up a bit...
              # arrays have all numeric indexes, in order; otherwise we assume a hash
              array = true
              i = 0
              vals.each do |key,value|
                if key != i # wrong index -> assume hash
                  array = false
                  break
                end
                i += 1
              end

              if array
                vals.collect! do |key,value|
                  value
                end
              else
                if assoc
                  val = vals.map {|v| v }
                else
                  val = Hash.new
                  vals.each do |key,value|
                    val[key] = value
                  end
                end
              end

            when 'O' # object, O:length:"class":length:{[attribute][value]...}
              # class name (lowercase in PHP, grr)
              len = string.read_until(':').to_i + 3 # quotes, seperator
              klass = string.read(len)[1...-2].capitalize.intern # read it, kill useless quotes

              # read the attributes
              attrs = []
              len = string.read_until('{').to_i

              len.times do
                attr = (do_unserialize(string, classmap, assoc))
                attrs << [attr.intern, (attr << '=').intern, do_unserialize(string, classmap, assoc)]
              end
              string.read(1)

              val = nil
              # See if we need to map to a particular object
              if classmap.has_key?(klass)
                val = classmap[klass].new
              elsif Struct.const_defined?(klass) # Nope; see if there's a Struct
                classmap[klass] = val = Struct.const_get(klass)
                val = val.new
              else # Nope; see if there's a Constant
                begin
                  classmap[klass] = val = Module.const_get(klass)

                  val = val.new
                rescue NameError # Nope; make a new Struct
                  classmap[klass] = Struct.new(klass.to_s, *attrs.collect { |v| v[0].to_s })
                  val = val.new
                end
              end

              attrs.each do |attr,attrassign,v|
                val.__send__(attrassign, v)
              end

            when 's' # string, s:length:"data";
              len = string.read_until(':').to_i + 3 # quotes, separator
              val = string.read(len)[1...-2] # read it, kill useless quotes

            when 'i' # integer, i:123
              val = string.read_until(';').to_i

            when 'd' # double (float), d:1.23
              val = string.read_until(';').to_f

            when 'N' # NULL, N;
              val = nil

            when 'b' # bool, b:0 or 1
              val = (string.read(2)[0] == ?1 ? true : false)

            else
              raise TypeError, "Unable to unserialize type '#{type}'"
            end

            val
          end # }}}
        end

    end
  end
end
