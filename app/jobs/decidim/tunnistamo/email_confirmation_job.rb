# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class EmailConfirmationJob < ApplicationJob
      queue_as :tunnistamo_email_confirmation

      def perform(user, email)
        return unless user
        return unless email

        user.update(tunnistamo_email_sent_to: email)
        user.update(tunnistamo_email_code_sent_at: Time.current)
        ::Decidim::Tunnistamo::EmailConfirmationMailer.send_code(user).deliver_now
      end
    end
  end
end
