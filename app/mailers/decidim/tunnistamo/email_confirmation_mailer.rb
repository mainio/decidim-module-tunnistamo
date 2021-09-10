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
          @code = user.tunnistamo_email_code

          mail(to: user.tunnistamo_email_sent_to, subject: "Email verification code")
        end
      end
    end
  end
end
