# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class EmailConfirmationMailer < Decidim::ApplicationMailer
      include Decidim::TranslationsHelper
      include Decidim::SanitizeHelper

      helper Decidim::TranslationsHelper

      def send_code(user)
        with_user(user) do
          @organization = user.organization
          @user = user
          @code = user.tunnistamo_email_code
          # wording = orders.count == 1 ? "email_subject.one" : "email_subject.other"

          # subject = I18n.t(
          #   wording,
          #   scope: "decidim.admin.vote_reminder_mailer.vote_reminder",
          #   order_count: orders.count
          # )

          mail(to: user.tunnistamo_email_sent_to, subject: "Email verification code")
        end
      end
    end
  end
end
