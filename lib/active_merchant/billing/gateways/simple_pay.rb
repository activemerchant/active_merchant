module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SimplePayGateway < Gateway

      require 'base64'
      require 'openssl'
      require 'json'

      self.test_url = 'https://sandbox.simplepay.hu/payment/v2/start'
      self.live_url = 'https://example.com/live'

      self.supported_countries = ['HU']
      self.default_currency = 'HUF'
      self.money_format = 'cents'
      self.supported_cardtypes = %i[visa master american_express discover]
      @@sdkVersion = 'SimplePayV2.1_Payment_PHP_SDK_2.0.7_190701:dd236896400d7463677a82a47f53e36e'
      @@language = 'HU'

      self.homepage_url = 'https://simplepay.hu/'
      self.display_name = 'Simple Pay'

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
        requires!(options, :merchantID, :merchantKey, :redirectURL)
        super
      end

      def purchase(options = {})
        post = {}  
        generate_purchase_data(post, options)
        return JSON[post]
        #commit('start', post)
      end

      def authorize(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options = {})
        commit('capture', post)
      end

      def refund(money, authorization, options = {})
        commit('refund', post)
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

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      def parseHeaderss(key, message)
        return {
          'Content-type' => 'application/json',
          'Signature' => Base64.encode64(OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha384'), key, message))
        }
      end

      private

      def generate_salt()
        chars = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        salt = (0...24).map { chars[rand(chars.length)] }.join
        return salt
      end

      def generate_timeout()
        
      end

      def generate_order_ref()
        return "EG" + Time.now.to_s[0..18]
        .gsub!('-', '')
        .gsub!(' ', '')
        .gsub!(':', '')
        + (1000 + rand(9999)).to_s
      end

      def generate_purchase_data(post, options)
          post[:salt] = generate_salt()
          post[:merchant] = :merchantID
          post[:orderRef] = generate_order_ref()
          post[:currency] = self.default_currency
          post[:customerEmail] = options[:email]
          post[:language] = @@language
          post[:sdkVersion] = @@sdkVersion
          post[:methods] = ['CARD']
          post[:total] = options[:ammount]
          post[:timeout] = '2019-09-11T19:14:08+00:00'
          post[:url] = :redirectURL
          post[:invoice] = {
            :name     => options[:name],
            :company  => options[:company],
            :country  => options[:country],
            :state    => options[:state],
            :city     => options[:city],
            :zip      => options[:zip],
            :address1 => options[:address1],
            :address2 => options[:address2],
            :phone    => options[:phone]
          }
      end

      def parseHeaders(key, message)
        return {
          'Content-type' => 'application/json',
          'Signature' => Base64.encode64(OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha384'), key, message))
        }
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        response = ssl_post(url, post_data(action, parameters, parseHeaders(:merchantKey, parameters)))

        parsed = JSON[response]

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response['some_avs_response_key']),
          cvv_result: CVVResult.new(response['some_cvv_response_key']),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response); end

      def message_from(response); end

      def authorization_from(response); end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end

    end
  end
end
