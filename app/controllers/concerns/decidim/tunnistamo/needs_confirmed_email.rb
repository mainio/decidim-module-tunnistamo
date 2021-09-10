# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module NeedsConfirmedEmail
      extend ActiveSupport::Concern

      included do
        before_action :email_confirmed, if: -> { current_user && current_user.tos_accepted? && from_tunnistamo? }
      end

      private

      def email_confirmed
        return unless request.format.html?
        return unless current_user
        return if current_user.managed
        return if current_user.tunnistamo_email_confirmed_at
        return unless current_user.tos_accepted?
        return if allowed_paths?

        raise "NOT ALLOWED PATH"
        redirect_to_confirm_email
      end

      def allowed_paths?
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
        Decidim::Authorization.where(name: "tunnistamo_idp", user: current_user).present?
      end
    end
  end
end
