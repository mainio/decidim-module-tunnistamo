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
        return broadcast(:invalid) if form.code != user.tunnistamo_email_code

        if email_taken?
          new_user = Decidim::User.find_by(email: user.tunnistamo_email_sent_to)
          update_authorization(user, new_user)
          new_user.tunnistamo_email_confirmed_at = Time.current
          new_user.save!
          bypass_sign_in(new_user)
          user.destroy
          return broadcast(:ok, new_user.email)
        end

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

      def email_taken?
        find_user = Decidim::User.find_by(email: user.tunnistamo_email_sent_to, organization: current_organization)
        return true if find_user && find_user.id != user.id

        false
      end

      def update_authorization(old_user, new_user)
        Decidim::Identity.find_by(provider: "tunnistamo", user: old_user, organization: current_organization).update(user: new_user)
        Decidim::Authorization.find_by(name: "tunnistamo_idp", user: old_user).update(user: new_user)
      end
    end
  end
end
