# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class ConfirmToken < Rectify::Command
      include Decidim::Tunnistamo::ConfirmUtilities

      attr_reader :form, :user

      def initialize(form)
        @form = form
        @user = form.user
      end

      def call
        return broadcast(:invalid) if form.invalid?

        if email_taken?
          return broadcast(:invalid) if form.conflicting_identity_or_authorization

          existing_user = Decidim::User.find_by(email: user.tunnistamo_email_sent_to)
          switch_user_and_delete_temp_user(existing_user, user)
          return broadcast(:ok, existing_user.email)
        end

        user.unconfirmed_email = user.tunnistamo_email_sent_to
        user.skip_confirmation_notification! # TODO: is this needed here?
        user.save!
        ::Decidim::User.confirm_by_token(form.confirmation_token)

        if updated_user && updated_user.errors.empty? && updated_user.confirmed_at.present?
          bypass_sign_in(updated_user)
          broadcast(:ok, updated_user.email)
        else
          broadcast(:invalid)
        end
      end

      private

      # We have to get user again because confirm_by_token doesn't update current user object
      def updated_user
        @updated_user ||= Decidim::User.find_by(
          id: user.id,
          organization: form.current_organization,
          confirmation_token: form.confirmation_token
        )
      end
    end
  end
end
