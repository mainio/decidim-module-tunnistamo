# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class ConfirmEmail < Rectify::Command
      def initialize(form, user)
        @form = form
        @user = user
      end

      def call
        return broadcast(:invalid) if form.invalid?
        return broadcast(:invalid) if user.tunnistamo_email_code_sent_at < Time.current - 30.minutes
        return broadcast(:invalid) if form.code.to_i != user.tunnistamo_email_code

        user.update(tunnistamo_email_confirmed_at: Time.current)

        broadcast(:ok)
      end

      private

      attr_reader :form, :user
    end
  end
end
