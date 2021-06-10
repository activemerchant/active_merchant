module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SimplePayGateway < Gateway

      require 'json'
      require 'base64'
      require 'openssl'

      self.test_url = {
        :start       => 'https://sandbox.simplepay.hu/payment/v2/start',
        :authorize   => 'https://sandbox.simplepay.hu/payment/v2/start',
        :capture     => 'https://sandbox.simplepay.hu/payment/v2/finish',
        :refund      => 'https://sandbox.simplepay.hu/payment/v2/refund',
        :query       => 'https://sandbox.simplepay.hu/payment/v2/query',

        :auto        => 'https://sandbox.simplepay.hu/pay/pay/auto/pspHU',
        
        :do          => 'https://sandbox.simplepay.hu/payment/v2/do',
        :dorecurring => 'https://sandbox.simplepay.hu/payment/v2/dorecurring',
        :cardquery   => 'https://sandbox.simplepay.hu/payment/v2/cardquery',
        :cardcancel  => 'https://sandbox.simplepay.hu/payment/v2/cardcancel',
        :tokenquery  => 'https://sandbox.simplepay.hu/payment/v2/tokenquery',
        :tokencancel => 'https://sandbox.simplepay.hu/payment/v2/tokencancel'
      }
      self.live_url = {
        :start       => 'https://secure.simplepay.hu/payment/v2/start',
        :authorize   => 'https://secure.simplepay.hu/payment/v2/start',
        :capture     => 'https://secure.simplepay.hu/payment/v2/finish',
        :refund      => 'https://secure.simplepay.hu/payment/v2/refund',
        :query       => 'https://secure.simplepay.hu/payment/v2/query',

        :auto        => 'https://secure.simplepay.hu/pay/pay/auto/pspHU',
        
        :do          => 'https://secure.simplepay.hu/payment/v2/do',
        :dorecurring => 'https://secure.simplepay.hu/payment/v2/dorecurring',
        :cardquery   => 'https://secure.simplepay.hu/payment/v2/cardquery',
        :cardcancel  => 'https://secure.simplepay.hu/payment/v2/cardcancel',
        :tokenquery  => 'https://secure.simplepay.hu/payment/v2/tokenquery',
        :tokencancel => 'https://secure.simplepay.hu/payment/v2/tokencancel'
      }

      self.supported_countries = ['HU']
      self.default_currency = 'HUF'
      self.money_format = 'cents'
      self.supported_cardtypes = %i[visa master maestro american_express]
      self.homepage_url = 'https://simplepay.hu/'
      self.display_name = 'Simple Pay'

      class_attribute :sdkVersion, :language, :allowed_ip
      self.sdkVersion = 'SimplePayV2.1_Payment_PHP_SDK_2.0.7_190701:dd236896400d7463677a82a47f53e36e'
      self.language = 'HU'
      self.allowed_ip = '94.199.53.96'

      STANDARD_ERROR_CODE_MAPPING = {
        '0'    => 'Sikeres művelet',
        '999'  => 'Általános hibakód.',
        '1529' => 'Belső hiba',
        '2003' => 'Megadott jelszó érvénytelen',
        '2004' => 'Általános hibakód',
        '2006' => 'Megadott kereskedő nem létezik',
        '2008' => 'Megadott e-mail nem megfelelő',
        '2010' => 'Megadott tranzakcióazonosító nem megfelelő',
        '2013' => 'Nincs elég fedezet a kártyán',
        '2016' => 'A felhasználó megszakította a fizetés',
        '2019' => 'Időtúllépés az elfogadói kommunikációban',
        '2021' => 'Kétfaktoros hitelesítés (SCA) szükséges',
        '2063' => 'Kártya inaktív',
        '2064' => 'Hibás bankkártya adatok',
        '2065' => 'Megadott kártya bevonása szükséges',
        '2066' => 'Kártya nem terhelhető / limittúllépés miatt',
        '2068' => 'Érvénytelen 3DS adat / kártyakibocsátó által elutasított 3DS authentikáció',
        '2070' => 'Invalid kártyatípus',
        '2071' => 'Hibás bankkártya adatok',
        '2072' => 'Kártya lejárat nem megfelelő',
        '2073' => 'A megadott CVC nem megfelelő',
        '2074' => 'Kártyabirtokos neve több, nint 32 karakter',
        '2078' => 'Kártyakibocsátó bank nem tudja megmondani a kártyatulajdonosnak a hiba okát',
        '2079' => 'A routingnak megfelelő elfogadók nem érhetőek el',
        '2999' => 'Belső hiba',
        '3002' => '3DS folyamat hiba',
        '3003' => '3DS folyamat hiba',
        '3004' => 'Redirect 3DS challenge folyamán',
        '3005' => '3D secure azonosítás szükséges',
        '3012' => '3D Secure folyamat megszakítása. pl. nem 3DS képes bankkártya miatt',
        '5000' => 'Általános hibakód.',
        '5010' => 'A fiók nem található.',
        '5011' => 'A tranzakció nem található',
        '5012' => 'Account nem egyezik meg',
        '5013' => 'A tranzakció már létezik (és nincs újraindíthatóként jelölve).',
        '5014' => 'A tranzakció nem megfelelő típusú',
        '5015' => 'A tranzakció éppen fizetés alatt',
        '5016' => 'Tranzakció időtúllépés (elfogadói/acquirer oldal felől érkező kérés során).',
        '5017' => 'A tranzakció meg lett szakítva (elfogadói/acquirer oldal felől érkező kérés során).',
        '5018' => 'A tranzakció már kifizetésre került (így újabb művelet nem kezdeményezhető).',
        '5020' => 'A kérésben megadott érték vagy az eredeti tranzakcióösszeg ("originalTotal") ellenőrzése sikertelen',
        '5021' => 'A tranzakció már lezárásra került (így újabb Finish művelet nem kezdeményezhető).',
        '5022' => 'A tranzakció nem a kéréshez elvárt állapotban van.',
        '5023' => 'Ismeretlen fiók devizanem.',
        '5026' => 'Tranzakció letiltva (sikertelen fraud-vizsgálat következtében).',
        '5030' => 'A művelet nem engedélyezett',
        '5040' => 'Tárolt kártya nem található',
        '5041' => 'Tárolt kártya lejárt',
        '5042' => 'Tárolt kártya inaktíválva',
        '5044' => 'Recurring nincs engedélyezve',
        '5048' => 'Recurring until szükséges',
        '5049' => 'Recurring until eltér',
        '5071' => 'Tárolt kártya érvénytelen hossz',
        '5072' => 'Tárolt kártya érvénytelen művelet',
        '5081' => 'Recurring token nem található',
        '5082' => 'Recurring token használatban',
        '5083' => 'Token times szükséges',
        '5084' => 'Token times túl nagy',
        '5085' => 'Token until szükséges',
        '5086' => 'Token until túl nagy',
        '5087' => 'Token maxAmount szükséges',
        '5088' => 'Token maxAmount túl nagy',
        '5089' => 'Recurring és oneclick regisztráció egyszerre nem indítható egy tranzakcióban',
        '5090' => 'Recurring token szükséges',
        '5091' => 'Recurring token inaktív',
        '5092' => 'Recurring token lejárt',
        '5093' => 'Recurring account eltérés',
        '5110' => 'Nem megfelelő visszatérítendő összeg. (Az opcionálisan megadható "refundTotal" érték nem lehet negatív és a jelenleg összesen még visszatéríthető összeget nem lépheti túl.)',
        '5111' => 'Az orderRef és a transactionId közül az egyik küldése kötelező',
        '5113' => 'A hívó kliensprogram megnevezése,verziószáma ("sdkVersion") kötelező.',
        '5201' => 'A kereskedői fiók azonosítója ("merchant") hiányzik.',
        '5213' => 'A kereskedői tranzakcióazonosító ("orderRef") hiányzik.',
        '5216' => 'Érvénytelen szállítási összeg',
        '5219' => 'Email cím ("customerEmail") hiányzik, vagy nem email fotmátumu.',
        '5220' => 'A tranzakció nyelve ("language") nem megfelelő',
        '5223' => 'A tranzakció pénzneme ("currency") nem megfelelő, vagy hiányzik.',
        '5302' => 'Nem megfelelő aláírás (signature) a beérkező kérésben. (A kereskedői API-ra érkező hívás aláírás-ellenőrzése sikertelen.)',
        '5303' => 'Nem megfelelő aláírás (signature) a beérkező kérésben. (A kereskedői API-ra érkező hívás aláírás-ellenőrzése sikertelen.)',
        '5304' => 'Időtúllépés miatt sikertelen aszinkron hívás.',
        '5305' => 'Sikertelen tranzakcióküldés a fizetési rendszer (elfogadói/acquirer oldal) felé.',
        '5306' => 'Sikertelen tranzakciólétrehozás',
        '5307' => 'A kérésben megadott devizanem ("currency") nem egyezik a fiókhoz beállítottal.',
        '5308' => 'A kérésben érkező kétlépcsős tranzakcióindítás nem engedélyezett a kereskedői fiókon',
        '5309' => 'Számlázási adatokban a címzett hiányzik ("name" természetes személy esetén, "company"jogi személy esetén).',
        '5310' => 'Számlázási adatokban a város kötelező.',
        '5311' => 'Számlázási adatokban az irányítószám kötelező.',
        '5312' => 'Számlázási adatokban a cím első sora kötelező.',
        '5313' => 'A megvásárlandó termékek listájában ("items") a termék neve ("title") kötelező.',
        '5314' => 'A megvásárlandó termékek listájában ("items") a termék egységára ("price") kötelező.',
        '5315' => 'A megvásárlandó termékek listájában ("items") a rendelt mennyiség ("amount") kötelezőpozitív egész szám.',
        '5316' => 'Szállítási adatokban a címzett kötelező ("name" természetes személy esetén, "company" jogi személy esetén).',
        '5317' => 'Szállítási adatokban a város kötelező.',
        '5318' => 'Szállítási adatokban az irányítószám kötelező.',
        '5319' => 'Szállítási adatokban a cím első sora kötelező.',
        '5320' => 'A hívó kliensprogram megnevezése,verziószáma ("sdkVersion") kötelező.',
        '5321' => 'Formátumhiba',
        '5322' => 'Érvénytelen ország',
        '5324' => 'Termékek listája ("items"), vagy tranzakciófőösszeg ("total") szükséges',
        '5325' => 'A visszairányítást vezérlő mezők közül legalább az egyik küldendő {(a) "url" - minden esetrevagy (b) "urls": különböző eseményekre egyenként megadhatóan}.',
        '5323' => 'Nem megfelelő véglegesítendő tranzakcióösszeg. (Az opcionálisan megadható "approveTotal" érték 0 és az eredeti tranzakció összege közötti érték kell legyen; Finish művelet során.)',
        '5326' => 'Hiányzó cardId',
        '5327' => 'Lekérdezendő kereskedői tranzakcióazonosítók ("orderRefs") maximális számának (50) túllépése.',
        '5328' => 'Lekérdezendő SimplePay tranzakcióazonosítók ("transactionIds") maximális számának (50) túllépése.',
        '5329' => 'Lekérdezendő tranzakcióindítás időszakában "from" az "until" időpontot meg kell előzze.',
        '5330' => 'Lekérdezendő tranzakcióindítás időszakában "from" és "until" együttesen adandó meg.',
        '5331' => 'Invaid API típus / A tranzakció nem V1, V2 vagy MW-s1',
        '5333' => 'Hiányzó tranzakció azonosító',
        '5337' => 'Hiba összetett adat szöveges formába írásakor.',
        '5339' => 'Lekérdezendő tranzakciókhoz tartozóan vagy az indítás időszaka ("from" és "until") vagy az azonosítólista ("orderRefs" vagy "transactionIds") megadandó.',
        '5343' => 'Invalid státusz kétlépcsős feloldáshoz',
        '5344' => 'Invalid státuz kétlépcsős lezáráshoz',
        '5345' => 'Áfa összege kisebb, mint 0',
        '5349' => 'A tranzakció nem engedélyezett az elszámoló fiókon (AMEX)',
        '5401' => 'Érvénytelen salt, nem 32-64 hosszú',
        '5413' => 'Létrejött utalási tranzakció',
        '5501' => 'Browser accept hiányzik',
        '5502' => 'Browser agent hiányzik',
        '5503' => 'Browser ip hiányzik',
        '5504' => 'Browser java hiányzik',
        '5505' => 'Browser lang hiányzik',
        '5506' => 'Browser color hiányzik',
        '5507' => 'Browser height hiányzik',
        '5508' => 'Browser width hiányzik',
        '5509' => 'Browser tz hiányzik',
        '5511' => 'Invalid browser accept',
        '5512' => 'Invalid browser agent',
        '5513' => 'Invalid browser IP',
        '5514' => 'Invalid browser java',
        '5515' => 'Invalid browser lang',
        '5516' => 'Invalid browser color',
        '5517' => 'Invalid browser height',
        '5518' => 'Invalid browser width',
        '5519' => 'Invalid browser tz',
        '5530' => 'Érvénytelen type',
        '5550' => 'Invalid JWT',
        '5813' => 'Kártya elutasítva',
      }

      def initialize(options = {})
        requires!(options, :merchantID, :merchantKEY, :redirectURL)
        if ['HUF', 'EUR', 'USD'].include? options[:currency]
          self.default_currency = options[:currency]
        end
        if !options.key?(:redirectURL)
          requires!(options, :urls)
          requires!(options[:urls], :success, :fail, :cancel, :timeout)
        end
        if !options.key?(:urls)
          requires!(options, :redirectURL)
        end
        super
      end

      def purchase(options = {})
        post = {}
        requires!(options, :amount, :email, :address)
        requires!(options[:address], :name, :country, :state, :city, :zip, :address1)
        if options.key?(:recurring)
          requires!(options, :times, :until, :maxAmount)
        end
        generate_post_data(:start, post, options)
        commit(:start, JSON[post])
      end

      def authorize(options = {})
        post = {}
        generate_post_data(:authorize, post, options)
        commit(:authorize, JSON[post])
      end

      def capture(options = {})
        post = {}
        generate_post_data(:capture, post, options)
        commit(:capture, JSON[post])
      end

      def refund(options = {})
        post = {}
        generate_post_data(:refund, post, options)
        commit(:refund, JSON[post])
      end

      def query(options = {})
        post = {}
        generate_post_data(:query, post, options)
        commit(:query, JSON[post])
      end

      def void(authorization, options = {})
        commit('void', post)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def auto(options = {})
        post = {}  
        generate_post_data(:auto, post, options)
        commit(:auto, JSON[post])
      end

      def dorecurring(options = {})
        post = {}  
        generate_post_data(:dorecurring, post, options)
        commit(:dorecurring, JSON[post])
      end

      def tokenquery(options = {})
        post = {}
        generate_post_data(:tokenquery, post, options)
        commit(:tokenquery, JSON[post])
      end

      def tokencancel(options = {})
        post = {}
        generate_post_data(:tokencancel, post, options)
        commit(:tokencancel, JSON[post])
      end

      def utilbackref(url){
        
      }

      private

      def generate_salt()
        chars = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        salt = (0...32).map { chars[rand(chars.length)] }.join
        return salt
      end

      def generate_timeout(timeout = @options[:timeout] || 10)
        now = Time.now + (timeout * 60)
        return now.strftime('%FT%T%:z')
      end

      def generate_order_ref()
        return "EG" + Time.now.to_s[0..18]
        .gsub!('-', '')
        .gsub!(' ', '')
        .gsub!(':', '')
        + (1000 + rand(9999)).to_s
      end

      def generate_post_data(action, post, options)
        #requires! handle
        case action

          when :start
            post[:salt] = generate_salt()
            post[:merchant] = @options[:merchantID]
            post[:orderRef] = options[:orderRef] || generate_order_ref()
            post[:currency] = self.default_currency
            post[:customerEmail] = options[:email]
            post[:language] = self.language
            post[:sdkVersion] = self.sdkVersion
            post[:methods] = ['CARD'] || options[:methods]
            post[:total] = options[:amount]
            post[:timeout] = generate_timeout
            post[:url] = @options[:redirectURL]
            post[:twoStep] = options[:twoStep] || false
            post[:invoice] = {
              :name     => options[:address][:name],
              :company  => options[:address][:company] || '',
              :country  => options[:address][:country],
              :state    => options[:address][:state],
              :city     => options[:address][:city],
              :zip      => options[:address][:zip],
              :address  => options[:address][:address1],
              :address2 => options[:address][:address2] || '',
              :phone    => options[:address][:phone] || ''
            }
            if options.key?(:items)
              post[:items] = options[:items]
            end
            if options.key?(:delivery)
              post[:delivery] = options[:delivery]
            end
            if options.key?(:threeDSReqAuthMethod)
              post[:threeDSReqAuthMethod] = options[:threeDSReqAuthMethod]
            end
            if options.key?(:recurring)
              post[:recurring] = {
                :times => options[:recurring][:times],
                :until => options[:recurring][:until],
                :maxAmount => options[:recurring][:maxAmount]
              }
            end
            if options.key?(:onlyCardReg)
              post[:onlyCardReg] = options[:onlyCardReg]
              post[:twoStep] = true
            end
            if options.key?(:maySelectEmail)
              post[:maySelectEmail] = options[:maySelectEmail]
            end
            if options.key?(:maySelectInvoice)
              post[:maySelectInvoice] = options[:maySelectInvoice]
            end
            if options.key?(:maySelectDelivery)
              post[:maySelectDelivery] = options[:maySelectDelivery]
            end

          when :authorize
            post[:salt] = generate_salt()
            post[:merchant] = @options[:merchantID]
            post[:orderRef] = options[:orderRef] || generate_order_ref()
            post[:currency] = self.default_currency
            post[:customerEmail] = options[:email]
            post[:language] = self.language
            post[:sdkVersion] = self.sdkVersion
            post[:methods] = ['CARD']
            post[:total] = options[:amount]
            post[:timeout] = generate_timeout
            post[:url] = @options[:redirectURL]
            post[:twoStep] = true,
            post[:invoice] = {
              :name     => options[:address][:name],
              :company  => options[:address][:company],
              :country  => options[:address][:country],
              :state    => options[:address][:state],
              :city     => options[:address][:city],
              :zip      => options[:address][:zip],
              :address  => options[:address][:address1],
              :address2 => options[:address][:address2],
              :phone    => options[:address][:phone]
            }
            if options.key?(:items)
              post[:items] = options[:items]
            end
            if options.key?(:threeDSReqAuthMethod)
              post[:threeDSReqAuthMethod] = options[:threeDSReqAuthMethod]
            end

          when :capture
            post[:salt] = generate_salt()
            post[:merchant] = @options[:merchantID]
            post[:orderRef] = options[:orderRef]
            post[:originalTotal] = options[:originalTotal]
            post[:approveTotal] = options[:approveTotal]
            post[:currency] = self.default_currency
            post[:sdkVersion] = self.sdkVersion

          when :refund
            post[:salt] = generate_salt()
            post[:merchant] = @options[:merchantID]
            post[:orderRef] = options[:orderRef]
            post[:refundTotal] = options[:refundTotal]
            post[:currency] = self.default_currency
            post[:sdkVersion] = self.sdkVersion
          
          when :query
            post[:salt] = generate_salt()
            post[:merchant] = @options[:merchantID]
            post[:transactionIds] = options[:transactionIds]
            post[:sdkVersion] = self.sdkVersion
            if options.key?(:detailed)
              post[:detailed] = options[:detailed]
            end
            if options.key?(:refund)
              post[:refund] = options[:refund]
            end

          when :auto
            post[:salt] = generate_salt()
            post[:merchant] = @options[:merchantID]
            post[:orderRef] = options[:orderRef] || generate_order_ref()
            post[:currency] = self.default_currency
            post[:customerEmail] = options[:email]
            post[:language] = self.language
            post[:sdkVersion] = self.sdkVersion
            post[:methods] = ['CARD']
            post[:total] = options[:amount]
            post[:timeout] = generate_timeout
            post[:url] = @options[:redirectURL]
            post[:twoStep] = false
            post[:cardData] = {
              :number => options[:credit_card].number,
              :expiry => expdate(options[:credit_card]),
              :cvc => options[:credit_card].verification_value,
              :holder => options[:credit_card].first_name + ' ' + options[:credit_card].last_name
            }
            post[:invoice] = {
              :name     => options[:address][:name],
              :company  => options[:address][:company],
              :country  => options[:address][:country],
              :state    => options[:address][:state],
              :city     => options[:address][:city],
              :zip      => options[:address][:zip],
              :address  => options[:address][:address1],
              :address2 => options[:address][:address2],
              :phone    => options[:address][:phone]
            }
            if options.key?(:items)
              post[:items] = options[:items]
            end
            if options.key?(:threeDS)
              post[:threeDSReqAuthMethod] = options[:threeDS][:threeDSReqAuthMethod]
              post[:threeDSReqAuthType]   = options[:threeDS][:threeDSReqAuthType]
              if options[:threeDS].key?(:browser)
                post[:browser] = {
                  :accept  => options[:threeDS][:browser][:accept],
                  :agent  => options[:threeDS][:browser][:agent],
                  :ip => options[:threeDS][:browser][:ip],
                  :java  => options[:threeDS][:browser][:java],
                  :lang => options[:threeDS][:browser][:lang],
                  :color => options[:threeDS][:browser][:color],
                  :height => options[:threeDS][:browser][:height],
                  :width => options[:threeDS][:browser][:width],
                  :tz => options[:threeDS][:browser][:tz]
                }
              end
            end

          when :dorecurring
            post[:salt] = generate_salt()
            post[:token] = options[:token]
            post[:merchant] = @options[:merchantID]
            post[:orderRef] = options[:orderRef] || generate_order_ref()
            post[:currency] = self.default_currency
            post[:customerEmail] = options[:email]
            post[:language] = self.language
            post[:sdkVersion] = self.sdkVersion
            post[:methods] = ['CARD']
            post[:total] = options[:amount]
            post[:timeout] = generate_timeout
            post[:type] = options[:type]
            post[:threeDSReqAuthMethod] = options[:threeDSReqAuthMethod]
            post[:invoice] = {
              :name     => options[:address][:name],
              :company  => options[:address][:company],
              :country  => options[:address][:country],
              :state    => options[:address][:state],
              :city     => options[:address][:city],
              :zip      => options[:address][:zip],
              :address  => options[:address][:address1],
              :address2 => options[:address][:address2],
              :phone    => options[:address][:phone]
            }
            if options.key?(:items)
              post[:items] = options[:items]
            end

          when :tokenquery
            post[:token]      = options[:token],
            post[:merchant]   = @options[:merchantID],
            post[:salt]       = generate_salt,
            post[:sdkVersion] = self.sdkVersion

          when :tokencancel
            post[:token]      = options[:token],
            post[:merchant]   = @options[:merchantID],
            post[:salt]       = generate_salt,
            post[:sdkVersion] = self.sdkVersion
        end
      end

      def parseHeaders(key, message)
        signature = Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest::SHA384.new, key, message)).gsub("\n", '')
        {
          'Content-Type' => 'application/json',
          'Signature' => signature
        }
      end

      def commit(action, parameters)
        puts parameters
        url = (test? ? test_url[action] : live_url[action])
        headers = parseHeaders(@options[:merchantKEY], parameters)
        response = JSON[ssl_post(url, parameters, headers)]

        #return response

        Response.new(
          success_from(response),
          message_from(response),
          response,
          #authorization: authorization_from(response),
          #avs_result: AVSResult.new(code: response['some_avs_response_key']),
          #cvv_result: CVVResult.new(response['some_cvv_response_key']),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        !response.key?('errorCodes')
      end

      def message_from(response)
        if success_from(response)
          return response
        else
          errors = []
          if response["errorCodes"].length > 0
            response["errorCodes"].each do |error|
              errors << STANDARD_ERROR_CODE_MAPPING[error.to_s]
            end
            return errors
          end
        end
      end

      def error_code_from(response)
        unless success_from(response)
          response["errorCodes"]
        end
      end

    end
  end
end