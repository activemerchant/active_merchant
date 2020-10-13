class VerbServlet < WEBrick::HTTPServlet::AbstractServlet
  %w[HEAD GET POST PUT DELETE].each do |verb|
    eval <<-METHOD
      def do_#{verb}(req, res)
        res.header['X-Request-Method'] = #{verb.dump}
        res.body = #{verb.dump}
      end
    METHOD
  end
end

