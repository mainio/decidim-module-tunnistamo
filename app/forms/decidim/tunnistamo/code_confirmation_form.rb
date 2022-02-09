# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class CodeConfirmationForm < Form
      mimic :tunnistamo_code_confirmation

      attribute :code

      validates :code, presence: true
      validate :max_attempts
      validate :code_not_expired
      validate :code_valid?

      def max_attempts
        return true if current_user.tunnistamo_failed_confirmation_attempts <= Decidim::User.maximum_attempts

        errors.add(
          :code,
          I18n.t("decidim.tunnistamo.email_confirmations.code_confirmation_form.errors.maximum_attempts")
        )

        false
      end

      def code_not_expired
        return true if current_user.tunnistamo_email_code_sent_at > Time.current - 30.minutes

        errors.add(
          :code,
          I18n.t("decidim.tunnistamo.email_confirmations.code_confirmation_form.errors.code_expired")
        )

        false
      end

      def code_valid?
        return true if code && code.scan(/\d+/).first == current_user.tunnistamo_email_code

        errors.add(
          :code,
          I18n.t("decidim.tunnistamo.email_confirmations.code_confirmation_form.errors.code_invalid")
        )

        false
      end
    end
  end
end
