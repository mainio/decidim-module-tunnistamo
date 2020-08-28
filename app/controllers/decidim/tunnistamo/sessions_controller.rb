# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class SessionsController < ::Decidim::Devise::SessionsController
      def tunnistamo_logout
        # This is handled already by OmniAuth
        redirect_to decidim.root_path
      end

      def destroy
        if session.delete("decidim-tunnistamo.signed_in")
          set_flash_message! :notice, :signed_out if end_user_session

          return redirect_to decidim_tunnistamo.user_tunnistamo_omniauth_logout_path
        end

        super
      end

      def post_logout
        redirect_path = stored_location_for(resource || :user) || decidim.root_path
        redirect_to redirect_path
      end

      private

      def end_user_session
        redirect_path = stored_location_for(resource || :user) || decidim.root_path

        # The ID token hint needs to be preserved in the session in order for
        # Tunnistamo to correctly remember where the user needs to be redirected
        # to after a successful sign out.
        id_token_hint = session['omniauth-tunnistamo.id_token']
        signed_out = (::Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
        store_location_for(:user, redirect_path)
        session['omniauth-tunnistamo.id_token'] = id_token_hint

        signed_out
      end
    end
  end
end
