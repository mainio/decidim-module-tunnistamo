# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class TokenConfirmationForm < Form
      attribute :user_id
      attribute :confirmation_token

      validates :confirmation_token, presence: true
      validates :user_id, presence: true

      validate :code_not_expired

      def user
        @user ||= Decidim::User.find_by(
          id: user_id,
          organization: current_organization,
          confirmation_token: confirmation_token
        )
      end

      def user_unconfirmed
        return true if user && user.confirmed_at.nil?

        errors.add(
          :token,
          I18n.t("decidim.tunnistamo.email_confirmations.token_confirmation_form.errors.user_confirmed")
        )

        false
      end

      def code_not_expired
        return true if user && user.tunnistamo_email_code_sent_at > Time.current - 30.minutes

        errors.add(
          :token,
          I18n.t("decidim.tunnistamo.email_confirmations.token_confirmation_form.errors.code_expired")
        )

        false
      end
    end
  end
end
