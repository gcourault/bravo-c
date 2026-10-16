require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'AuthData' do
  describe '.fetch' do
    after { File.delete(Bravo::AuthData.todays_data_file_name) if File.exist?(Bravo::AuthData.todays_data_file_name) }

    it 'creates constants for todays data' do
      Bravo::Wsaa.stub(:login) do
        Bravo::Wsaa.write_yaml(['TOK', 'SIG', (Time.now + 3600).iso8601])
      end

      Bravo::AuthData.fetch

      Bravo::TOKEN.should == 'TOK'
      Bravo::SIGN.should == 'SIG'
    end
  end
end
