# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class CreateEmailConfirmation < Rectify::Command
      def initialize(form, user)
        @form = form
        @user = user
      end

      def call
        return broadcast(:invalid) if form.invalid?
        return broadcast(:invalid) unless form.email

        code = rand(100_000..999_999)
        user.update(tunnistamo_email_code: code)

        ::Decidim::Tunnistamo::EmailConfirmationJob.perform_now(user, form.email)

        broadcast(:ok)
      end

      private

      attr_reader :form, :user
    end
  end
end
