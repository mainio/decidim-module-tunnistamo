# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class ConfirmCode < Rectify::Command
      include Decidim::Tunnistamo::ConfirmUtilities

      attr_reader :form, :user

      def initialize(form, user)
        @user = user
        @form = form
      end

      def call
        unless form.code_valid?
          user.update(tunnistamo_failed_confirmation_attempts: user.tunnistamo_failed_confirmation_attempts + 1)
          form.max_attempts
          return broadcast(:invalid)
        end
        return broadcast(:invalid) if form.invalid?

        if email_taken?
          return broadcast(:invalid) if conflicting_identity_or_authorization

          existing_user = Decidim::User.find_by(email: user.tunnistamo_email_sent_to)
          switch_user_and_delete_temp_user!(existing_user, user)
          return broadcast(:ok, existing_user.email)
        end

        user.email = user.tunnistamo_email_sent_to

        if user.valid?
          user.skip_confirmation_notification!
          user.save!
          user.confirm

          broadcast(:ok, user.email)
        else
          broadcast(:invalid)
        end
      end
    end
  end
end
