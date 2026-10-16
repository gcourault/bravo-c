require 'spec_helper'

describe 'Wsaa' do
  describe '.build_tra' do
    it 'sets the body for the ticket request' do
      tra = Bravo::Wsaa.build_tra

      tra.should include('<loginTicketRequest version="1.0">')
      tra.should include('<service>wsfe</service>')
      tra.should match(%r{<uniqueId>\d+</uniqueId>})
    end
  end

  describe '.build_cms' do
    it 'returns the Base64 CMS signed with the certificate, containing the tra' do
      tra = Bravo::Wsaa.build_tra
      der = Base64.decode64(Bravo::Wsaa.build_cms(tra))
      p7  = OpenSSL::PKCS7.new(der)

      der.should include(tra)
      p7.verify([], OpenSSL::X509::Store.new, nil, OpenSSL::PKCS7::NOVERIFY).should == true
      p7.certificates.first.to_der.should ==
        OpenSSL::X509::Certificate.new(File.read(Bravo.cert)).to_der
    end
  end

  describe '.call_wsaa' do
    let(:url) { Bravo::AuthData.wsaa_url }

    it 'returns token, sign and expiration time' do
      body = '&lt;loginTicketResponse&gt;&lt;header&gt;&lt;expirationTime&gt;2030-01-01T10:00:00.000-03:00' \
             '&lt;/expirationTime&gt;&lt;/header&gt;&lt;credentials&gt;&lt;token&gt;TOK&lt;/token&gt;' \
             '&lt;sign&gt;SIG&lt;/sign&gt;&lt;/credentials&gt;&lt;/loginTicketResponse&gt;'
      WebMock.stub_request(:post, url).to_return(body: body)

      Bravo::Wsaa.call_wsaa('<req/>').should == ['TOK', 'SIG', '2030-01-01T10:00:00.000-03:00']
    end

    it 'raises with the fault message when there are no credentials' do
      WebMock.stub_request(:post, url).to_return(body: '<faultstring>cert expirado</faultstring>')

      expect { Bravo::Wsaa.call_wsaa('<req/>') }.to raise_error(Bravo::WsaaError, /cert expirado/)
    end
  end

  describe '.write_yaml and AuthData.valid_data_file?' do
    before { File.delete(Bravo::AuthData.todays_data_file_name) if File.exist?(Bravo::AuthData.todays_data_file_name) }
    after  { File.delete(Bravo::AuthData.todays_data_file_name) if File.exist?(Bravo::AuthData.todays_data_file_name) }

    it 'caches a token that has not expired' do
      Bravo::Wsaa.write_yaml(['T', 'S', (Time.now + 3600).iso8601])

      Bravo::AuthData.valid_data_file?.should == true
      File.stat(Bravo::AuthData.todays_data_file_name).mode.to_s(8).should end_with('600')
    end

    it 'does not reuse an expired token' do
      Bravo::Wsaa.write_yaml(['T', 'S', (Time.now - 10).iso8601])

      Bravo::AuthData.valid_data_file?.should == false
    end
  end
end
