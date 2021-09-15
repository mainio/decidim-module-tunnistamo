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
        return broadcast(:invalid) if form.invalid?

        if email_taken?
          existing_user = Decidim::User.find_by(email: user.tunnistamo_email_sent_to)
          switch_user_and_delete_temp_user(existing_user)
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
