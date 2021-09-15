# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class CodeConfirmationForm < Form
      attribute :code

      validate :email_not_expired
      validate :code_valid?

      def email_not_expired
        current_user.tunnistamo_email_code_sent_at > Time.current - 30.minutes
      end

      def code_valid?
        code == current_user.tunnistamo_email_code
      end
    end
  end
end
