# frozen_string_literal: true

require "omniauth/rails_csrf_protection/token_verifier"

module Decidim
  module Tunnistamo
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::Tunnistamo

      def self.customizations_after_hook
        if defined?(Decidim::Privacy)
          "decidim_privacy.add_customizations"
        else
          "decidim.action_controller"
        end
      end

      # To make this work with the privacy module, ensure that these incldues
      # happen AFTER the privacy module.
      initializer "decidim_tunnistamo.customizations", after: customizations_after_hook do
        config.to_prepare do
          Decidim::ApplicationController.include Decidim::Tunnistamo::NeedsConfirmedEmail
          Decidim::CreateOmniauthRegistration.include Decidim::Tunnistamo::CreateOmniauthRegistrationOverride
          Decidim::OmniauthRegistrationForm.include Decidim::Tunnistamo::OmniauthRegistrationFormExtensions
        end
      end

      routes do
        resources :email_confirmations, only: [:new, :create] do
          collection do
            get :preview
            get :confirm_with_token
            post :confirm_with_code
          end
        end

        devise_scope :user do
          # Manually map the omniauth routes for Devise because the default
          # routes are mounted by core Decidim. This is because we want to map
          # these routes to the local callbacks controller instead of the
          # Decidim core.
          # See: https://git.io/fjDz1
          match(
            "/users/auth/tunnistamo",
            to: "omniauth_callbacks#passthru",
            as: "user_tunnistamo_omniauth_authorize",
            via: [:get, :post]
          )

          match(
            "/users/auth/tunnistamo/callback",
            to: "omniauth_callbacks#tunnistamo",
            as: "user_tunnistamo_omniauth_callback",
            via: [:get, :post]
          )

          match(
            "/users/auth/tunnistamo/logout",
            to: "sessions#tunnistamo_logout",
            as: "user_tunnistamo_omniauth_logout",
            via: [:get, :post]
          )

          match(
            "/users/auth/tunnistamo/post_logout",
            to: "sessions#post_logout",
            as: "user_tunnistamo_omniauth_post_logout",
            via: [:get]
          )

          # Manually map the sign out path in order to control the sign out
          # flow through OmniAuth when the user signs out from the service.
          # In these cases, the user needs to be also signed out from Suomi.fi
          # which is handled by the OmniAuth strategy.
          match(
            "/users/sign_out",
            to: "sessions#destroy",
            as: "destroy_user_session",
            via: [:delete, :post]
          )
        end
      end

      initializer "decidim_tunnistamo.configure_devise", before: "decidim_core.after_initializers_folder" do
        next unless Decidim::Tunnistamo.confirm_emails

        # By default in Decidim this is set as 0. We need to have unconfirmed
        # access so that participant can verify his/her email.
        Decidim.unconfirmed_access_for = 1000.days
      end

      initializer "decidim_tunnistamo.mount_routes", before: :add_routing_paths do
        # Mount the engine routes to Decidim::Core::Engine because otherwise
        # they would not get mounted properly. Note also that we need to prepend
        # the routes in order for them to override Decidim's own routes for the
        # "tunnistamo" authentication.
        Decidim::Core::Engine.routes.prepend do
          mount Decidim::Tunnistamo::Engine => "/"
        end
      end

      initializer "decidim_tunnistamo.setup", before: "devise.omniauth" do
        next unless Decidim::Tunnistamo.configured?

        OmniAuth.config.request_validation_phase = ::OmniAuth::RailsCsrfProtection::TokenVerifier.new

        # Configure the SAML OmniAuth strategy for Devise
        ::Devise.setup do |config|
          config.omniauth(
            :tunnistamo,
            Decidim::Tunnistamo.omniauth_settings
          )
        end

        # Customized version of Devise's OmniAuth failure app in order to handle
        # the failures properly. Without this, the failure requests would end
        # up in an ActionController::InvalidAuthenticityToken exception.
        devise_failure_app = OmniAuth.config.on_failure
        OmniAuth.config.on_failure = proc do |env|
          if env["PATH_INFO"] =~ %r{^/users/auth/tunnistamo(/.*)?}
            env["devise.mapping"] = ::Devise.mappings[:user]
            Decidim::Tunnistamo::OmniauthCallbacksController.action(
              :failure
            ).call(env)
          else
            # Call the default for others.
            devise_failure_app.call(env)
          end
        end
      end

      initializer "decidim_tunnistamo.mail_interceptors" do
        ActionMailer::Base.register_interceptor(
          MailInterceptors::GeneratedRecipientsInterceptor
        )
      end
    end
  end
end
