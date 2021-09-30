# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class OmniauthCallbacksController < ::Decidim::Devise::OmniauthRegistrationsController
      # Make the view helpers available needed in the views
      helper Decidim::Tunnistamo::Engine.routes.url_helpers
      helper_method :omniauth_registrations_path

      skip_before_action :verify_authenticity_token, only: [:tunnistamo, :failure]
      skip_after_action :verify_same_origin_request, only: [:tunnistamo, :failure]

      # This is called always after the user returns from the authentication
      # flow from the Tunnistamo identity provider.
      def tunnistamo
        # This needs to be here in order to send the logout request to
        # Tunnistamo in case the sign in fails. Note that the Tunnistamo sign
        # out flow does not currently support the "post_logout_redirect_uri"
        # parameter, so the user may be left at Tunnistamo after the sign out.
        # This is more secure but may leave some users confused. Should only
        # happen if the authentication validation fails.
        session["decidim-tunnistamo.signed_in"] = true

        authenticator.validate!

        if user_signed_in?
          # The user is most likely returning from an authorization request
          # because they are already signed in. In this case, add the
          # authorization and redirect the user back to the authorizations view.

          # Make sure the user has an identity created in order to aid future
          # Tunnistamo sign ins. In case this fails, it will raise a
          # Decidim::Tunnistamo::Authentication::IdentityBoundToOtherUserError
          # which is handled below.
          authenticator.identify_user!(current_user)

          # Add the authorization for the user
          return fail_authorize unless authorize_user(current_user)

          if authenticator.strong_identity_provider?
            current_user.forget_me!
            cookies.delete :remember_user_token, domain: current_organization.host
            cookies.delete :remember_admin_token, domain: current_organization.host
            cookies.update response.cookies
          end

          # Show the success message and redirect back to the authorizations
          flash[:notice] = t(
            "authorizations.create.success",
            scope: "decidim.tunnistamo.verification"
          )
          return redirect_to(
            stored_location_for(resource || :user) ||
            decidim_verifications.authorizations_path
          )
        end

        # Normal authentication request, proceed with Decidim's internal logic.
        send(:create)
      rescue Decidim::Tunnistamo::Authentication::ValidationError => e
        fail_authorize(e.validation_key)
      rescue Decidim::Tunnistamo::Authentication::IdentityBoundToOtherUserError
        fail_authorize(:identity_bound_to_other_user)
      end

      # This is overridden method from the Devise controller helpers
      # This is called when the user is successfully authenticated which means
      # that we also need to add the authorization for the user automatically
      # because a succesful Tunnistamo authentication means the user has been
      # successfully authorized as well.
      def sign_in_and_redirect(resource_or_scope, *args)
        # Add authorization for the user
        if resource_or_scope.is_a?(::Decidim::User)
          return fail_authorize unless authorize_user(resource_or_scope)
        end

        super
      end

      # Disable authorization redirect for the first login
      def first_login_and_not_authorized?(_user)
        false
      end

      private

      def authorize_user(user)
        authenticator.authorize_user!(user)
      rescue Decidim::Tunnistamo::Authentication::AuthorizationBoundToOtherUserError
        nil
      end

      def fail_authorize(failure_message_key = :already_authorized)
        flash[:alert] = t(
          "failure.#{failure_message_key}",
          scope: "decidim.tunnistamo.omniauth_callbacks"
        )

        if session.delete("decidim-tunnistamo.signed_in")
          return redirect_to(
            decidim_tunnistamo.user_tunnistamo_omniauth_logout_path
          )
        end

        redirect_path = stored_location_for(resource || :user) || decidim.root_path
        redirect_to redirect_path
      end

      # Needs to be specifically defined because the core engine routes are not
      # all properly loaded for the view and this helper method is needed for
      # defining the omniauth registration form's submit path.
      def omniauth_registrations_path(resource)
        Decidim::Core::Engine.routes.url_helpers.omniauth_registrations_path(resource)
      end

      # Private: Create form params from omniauth hash
      # Since we are using trusted omniauth data we are generating a valid signature.
      def user_params_from_oauth_hash
        authenticator.user_params_from_oauth_hash
      end

      def authenticator
        @authenticator ||= Decidim::Tunnistamo.authenticator_for(
          current_organization,
          oauth_hash
        )
      end

      def verified_email
        authenticator.verified_email
      end
    end
  end
end
