# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class SendConfirmationEmail < Rectify::Command
      def initialize(form, user)
        @form = form
        @user = user
      end

      def call
        return broadcast(:invalid) if form.invalid?
        return broadcast(:invalid) unless form.email

        user.update(tunnistamo_email_code: create_code, unconfirmed_email: form.email, tunnistamo_failed_confirmation_attempts: 0)
        user.send(:generate_confirmation_token!) unless user.confirmation_token

        ::Decidim::Tunnistamo::SendConfirmationEmailJob.perform_now(user, form.email)

        broadcast(:ok)
      end

      private

      def create_code
        six_digits = "%06d"
        format(six_digits, rand(0..999_999))
      end

      attr_reader :form, :user
    end
  end
end
