# frozen_string_literal: true

require "omniauth"

require_relative "tunnistamo/version"
require_relative "tunnistamo/engine"
require_relative "tunnistamo/authentication"
require_relative "tunnistamo/verification"
require_relative "tunnistamo/mail_interceptors"

module Decidim
  module Tunnistamo
    include ActiveSupport::Configurable

    @configured = false

    # Defines the email domain for the auto-generated email addresses for the
    # user accounts. This is only used if the user does not have an email
    # address returned by Tunnistamo. Not all people have email address stored
    # there and some people may have incorrect email address stored there.
    #
    # In case this is defined, the user will be automatically assigned an email
    # such as "tunnistamo-identifier@auto-email-domain.fi" upon their
    # registration.
    #
    # In case this is not defined, the default is the organization's domain.
    config_accessor :auto_email_domain

    # Allows customizing the authorization workflow e.g. for adding custom
    # workflow options or configuring an action authorizer for the
    # particular needs.
    config_accessor :workflow_configurator do
      lambda do |workflow|
        # By default, expiration is set to 0 minutes which means it will
        # never expire.
        workflow.expires_in = 0.minutes
      end
    end

    # Allows customizing parts of the authentication flow such as validating
    # the authorization data before allowing the user to be authenticated.
    config_accessor :authenticator_class do
      Decidim::Tunnistamo::Authentication::Authenticator
    end

    # Allows customizing how the authorization metadata gets collected from
    # the OAuth attributes passed from the authorization endpoint.
    config_accessor :metadata_collector_class do
      Decidim::Tunnistamo::Verification::MetadataCollector
    end

    def self.configured?
      return false unless Rails.application.secrets.omniauth.has_key?(:tunnistamo)

      Rails.application.secrets.omniauth[:tunnistamo][:enabled]
    end

    def self.authenticator_for(organization, oauth_hash)
      authenticator_class.new(organization, oauth_hash)
    end

    def self.omniauth_settings
      secrets = Rails.application.secrets.omniauth[:tunnistamo]
      server_uri = secrets[:server_uri]
      client_id = secrets[:client_id]
      client_secret = secrets[:client_secret]

      auth_uri = URI.parse(server_uri)
      {
        issuer: "#{server_uri}/openid",
        client_options: {
          port: auth_uri.port,
          scheme: auth_uri.scheme,
          host: auth_uri.host,
          identifier: client_id,
          secret: client_secret,
          redirect_uri: "#{application_host}/users/auth/tunnistamo/callback"
        },
        post_logout_redirect_uri: application_host
      }
    end

    # Used to determine the callback URLs.
    def self.application_host
      conf = Rails.application.config
      url_options = conf.action_controller.default_url_options
      url_options = conf.action_mailer.default_url_options if !url_options || !url_options[:host]
      url_options ||= {}

      host = url_options[:host]
      port = url_options[:port]
      if host.blank?
        # Default to local development environment
        host = "http://localhost"
        port ||= 3000
      elsif host !~ %r{^https?://}
        protocol = url_options[:protocol] || "https"
        host = "#{protocol}://#{host}"
      end

      return "#{host}:#{port}" if port && ![80, 443].include?(port.to_i)

      host
    end
  end
end
