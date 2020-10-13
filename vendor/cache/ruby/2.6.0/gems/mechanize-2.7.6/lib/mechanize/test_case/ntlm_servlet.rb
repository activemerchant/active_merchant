class NTLMServlet < WEBrick::HTTPServlet::AbstractServlet

  def do_GET(req, res)
    if req['Authorization'] =~ /^NTLM (.*)/ then
      authorization = $1.unpack('m*').first

      if authorization =~ /^NTLMSSP\000\001/ then
        type_2 = 'TlRMTVNTUAACAAAADAAMADAAAAABAoEAASNFZ4mr' \
          'ze8AAAAAAAAAAGIAYgA8AAAARABPAE0AQQBJAE4A' \
          'AgAMAEQATwBNAEEASQBOAAEADABTAEUAUgBWAEUA' \
          'UgAEABQAZABvAG0AYQBpAG4ALgBjAG8AbQADACIA' \
          'cwBlAHIAdgBlAHIALgBkAG8AbQBhAGkAbgAuAGMA' \
          'bwBtAAAAAAA='

        res['WWW-Authenticate'] = "NTLM #{type_2}"
        res.status = 401
      elsif authorization =~ /^NTLMSSP\000\003/ then
        res.body = 'ok'
      else
        res['WWW-Authenticate'] = 'NTLM'
        res.status = 401
      end
    else
      res['WWW-Authenticate'] = 'NTLM'
      res.status = 401
    end
  end

end

