require 'tmpdir'
require 'yaml'
require 'time'

module Bravo

  # This class handles authorization data
  #
  class AuthData

    class << self

      attr_accessor :environment

      # Fetches WSAA Authorization Data to build the datafile for the day.
      # It requires the private key file and the certificate to exist and
      # to be configured as Bravo.pkey and Bravo.cert
      #
      def fetch
        unless File.exist?(Bravo.pkey)
          raise "Archivo de llave privada no encontrado en #{ Bravo.pkey }"
        end

        unless File.exist?(Bravo.cert)
          raise "Archivo certificado no encontrado en #{ Bravo.cert }"
        end

        Bravo::Wsaa.login unless valid_data_file?

        YAML.load_file(todays_data_file_name).each do |k, v|
          next if k.to_s == 'expires_at'
          name = k.to_s.upcase.to_sym
          Bravo.send(:remove_const, name) if Bravo.const_defined?(name, false)
          Bravo.const_set(name, v)
        end
      end

      # Returns the authorization hash, containing the Token, Signature and Cuit
      # @return [Hash]
      #
      def auth_hash
        fetch unless Bravo.constants.include?(:TOKEN) && Bravo.constants.include?(:SIGN) && valid_data_file?
        { 'Token' => Bravo::TOKEN, 'Sign'  => Bravo::SIGN, 'Cuit'  => Bravo.cuit }
      end

      # Returns the right wsaa url for the specific environment
      # @return [String]
      #
      def wsaa_url
        raise 'Environment not sent to either :test or :production' unless Bravo::URLS.keys.include? environment
        Bravo::URLS[environment][:wsaa]
      end

      # Returns the right wsfe url for the specific environment
      # @return [String]
      #
      def wsfe_url
        raise 'Environment not sent to either :test or :production' unless Bravo::URLS.keys.include? environment
        Bravo::URLS[environment][:wsfe]
      end

      # Creates the data file name for a cuit number, environment and the current day
      # @return [String]
      #
      def todays_data_file_name
        File.join(Dir.tmpdir, "bravo_#{ Bravo.cuit }_#{ environment }_#{ Time.new.strftime('%Y_%m_%d') }.yml")
      end

      # Tells whether the cached token exists and is not about to expire.
      # @return [Boolean]
      #
      def valid_data_file?
        return false unless File.exist?(todays_data_file_name)
        expires_at = YAML.load_file(todays_data_file_name)['expires_at']
        !expires_at.nil? && Time.parse(expires_at.to_s) > Time.now + 60
      end
    end
  end
end
