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
          existing_user = Decidim::User.find_by(email: user.tunnistamo_email_sent_to)
          switch_user_and_delete_temp_user(existing_user)
          return broadcast(:ok, existing_user.email)
        end

        ::Decidim::User.confirm_by_token(form.confirmation_token)

        # We have to get user again because confir_by_token doesn't update current user object
        updated_user = Decidim::User.find_by(id: user.id, organization: current_organization)

        if updated_user && updated_user.errors.empty?
          broadcast(:ok, updated_user.email)
        else
          broadcast(:invalid)
        end
      end
    end
  end
end
