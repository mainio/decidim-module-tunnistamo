# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module NeedsConfirmedEmail
      extend ActiveSupport::Concern

      included do
        before_action :email_confirmed, if: -> { ::Decidim::Tunnistamo.confirm_emails && current_user }
      end

      private

      def email_confirmed
        return unless request.format.html?
        return if current_user.confirmed_at
        return unless current_user.tos_accepted?
        return if current_user.managed
        return unless from_tunnistamo?
        return if tunnistamo_email_confirmation_allowed_paths?

        redirect_to_confirm_email
      end

      def tunnistamo_email_confirmation_allowed_paths?
        allowed_paths = [
          decidim_tunnistamo.new_email_confirmation_path,
          decidim_tunnistamo.email_confirmations_path,
          decidim_tunnistamo.preview_email_confirmation_path,
          decidim_tunnistamo.complete_email_confirmation_path
        ]
        allowed_paths.find { |el| el.split("?").first == request.path }
      end

      def redirect_to_confirm_email
        redirect_to decidim_tunnistamo.new_email_confirmation_path
      end

      def from_tunnistamo?
        return true if Decidim::Authorization.find_by(name: "tunnistamo_idp", user: current_user)

        false
      end
    end
  end
end
