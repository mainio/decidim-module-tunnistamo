# frozen_string_literal: true

require "omniauth"

require_relative "tunnistamo/version"
require_relative "tunnistamo/engine"
require_relative "tunnistamo/authentication"
require_relative "tunnistamo/verification"
require_relative "tunnistamo/mail_interceptors"

module Decidim
  module Tunnistamo
    autoload :FormBuilder, "decidim/tunnistamo/form_builder"

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

    # After successful user authorization with strong identification
    # providers (Suomi.fi/school/etc.), forget remember me.
    config_accessor :strong_identity_providers

    # The requested OpenID scopes for the Omniauth strategy. The data returned
    # by the authentication service can differ depending on the defined scopes.
    #
    # See: https://openid.net/specs/openid-connect-basic-1_0.html#Scopes
    config_accessor :scope do
      [:openid, :email, :profile]
    end

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

    # Enables email confirmation process after successful login
    config_accessor :confirm_emails do
      false
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

      auth_uri = URI.parse(server_uri) if server_uri
      {
        issuer: "#{server_uri}/openid",
        scope: scope,
        client_options: {
          port: auth_uri&.port,
          scheme: auth_uri&.scheme,
          host: auth_uri&.host,
          identifier: client_id,
          secret: client_secret,
          redirect_uri: "#{application_host}/users/auth/tunnistamo/callback"
        },
        post_logout_redirect_uri: "#{application_host}/users/auth/tunnistamo/post_logout"
      }
    end

    # Used to determine the callback URLs.
    def self.application_host
      conf = Rails.application.config
      url_options = conf.action_controller.default_url_options
      url_options = conf.action_mailer.default_url_options if !url_options || !url_options[:host]
      url_options ||= {}
      host, port = host_and_port_setting(url_options)

      return "#{host}:#{port}" if port && [80, 443].exclude?(port.to_i)

      host
    end

    def self.host_and_port_setting(url_options)
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
      [host, port]
    end

    private_class_method :host_and_port_setting
  end
end
