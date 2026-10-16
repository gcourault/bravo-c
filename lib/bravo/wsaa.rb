# -*- encoding: utf-8 -*-
require 'openssl'
require 'net/http'
require 'cgi'
require 'time'
require 'yaml'

module Bravo
  # Raised when the WSAA rejects a login request or answers something unexpected.
  #
  class WsaaError < StandardError; end

  # Authorization class. Handles interactions wiht the WSAA, to provide
  # valid token and signature that will last for 12 hours.
  #
  class Wsaa
    # Main method for authentication and authorization.
    # When successful, produces the yaml file with auth data.
    #
    def self.login
      tra   = build_tra
      cms   = build_cms(tra)
      req   = build_request(cms)
      auth  = call_wsaa(req)

      write_yaml(auth)
    end

    # Builds the xml for the 'Ticket de Requerimiento de Acceso'
    # @return [String] containing the request body
    #
    def self.build_tra
      @now = (Time.now) - 120
      @from = @now.strftime('%FT%T%:z')
      @to   = (@now + ((12*60*60))).strftime('%FT%T%:z')
      @id   = @now.strftime('%s')
      tra  = <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<loginTicketRequest version="1.0">
  <header>
    <uniqueId>#{ @id }</uniqueId>
    <generationTime>#{ @from }</generationTime>
    <expirationTime>#{ @to }</expirationTime>
  </header>
  <service>wsfe</service>
</loginTicketRequest>
EOF
      return tra
    end

    # Signs the TRA with the configured certificate and private key (PKCS#7,
    # content included, DER encoded) using Ruby's OpenSSL bindings.
    # @return [String] the Base64 encoded CMS
    #
    def self.build_cms(tra)
      cert = OpenSSL::X509::Certificate.new(File.read(Bravo.cert))
      key  = OpenSSL::PKey.read(File.read(Bravo.pkey))
      p7   = OpenSSL::PKCS7.sign(cert, key, tra, [], OpenSSL::PKCS7::BINARY)

      [p7.to_der].pack('m0')
    end

    # Builds the CMS request to log in to the server
    # @return [String] the cms body
    #
    def self.build_request(cms)
      request = <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://wsaa.view.sua.dvadac.desein.afip.gov">
  <SOAP-ENV:Body>
    <ns1:loginCms>
      <ns1:in0>
#{ cms }
      </ns1:in0>
    </ns1:loginCms>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
XML
      return request
    end

    # Calls the WSAA with the request built by build_request
    # @return [Array] with the token, signature and expiration time
    # @raise [Bravo::WsaaError] if the WSAA answers with a fault or no credentials
    #
    def self.call_wsaa(req)
      uri  = URI(Bravo::AuthData.wsaa_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = uri.scheme == 'https'
      http.open_timeout = http.read_timeout = 30

      post = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'text/xml; charset=utf-8', 'SOAPAction' => '""')
      post.body = req

      response = CGI.unescapeHTML(http.request(post).body.to_s)

      token   = response[/<token>(.+?)<\/token>/m, 1]
      sign    = response[/<sign>(.+?)<\/sign>/m, 1]
      expires = response[/<expirationTime>(.+?)<\/expirationTime>/m, 1]

      unless token && sign
        fault = response[/<faultstring>(.+?)<\/faultstring>/m, 1]
        raise WsaaError, "El WSAA no devolvió credenciales: #{ fault || response[0, 200] }"
      end

      [token, sign, expires]
    end

    # Writes the token, signature and expiration time to a YAML file
    # readable only by the current user.
    #
    def self.write_yaml(certs)
      token, sign, expires = certs
      data = { 'token' => token, 'sign' => sign,
               'expires_at' => (expires ? Time.parse(expires) : Time.now + 11 * 60 * 60).iso8601 }

      File.write(Bravo::AuthData.todays_data_file_name, data.to_yaml, perm: 0600)
    end
  end
end
