# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class ConfirmEmail < Rectify::Command
      def initialize(form, user)
        @user = user
        @form = form
      end

      def call
        return broadcast(:invalid) if form.invalid?
        return broadcast(:invalid) if user.tunnistamo_email_code_sent_at < Time.current - 30.minutes
        return broadcast(:invalid) if form.code.to_i != user.tunnistamo_email_code

        user.email = user.tunnistamo_email_sent_to
        user.tunnistamo_email_confirmed_at = Time.current

        if user.valid?
          user.skip_confirmation_notification!
          user.save!
          user.confirm

          broadcast(:ok, user.email)
        else
          broadcast(:invalid)
        end
      end

      private

      attr_reader :form, :user
    end
  end
end
