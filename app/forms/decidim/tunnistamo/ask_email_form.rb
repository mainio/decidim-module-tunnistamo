# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class AskEmailForm < Form
      attribute :email

      validates :email, presence: true, 'valid_email_2/email': { disposable: true }
      validate :can_take_email?

      def can_take_email?
        find_user = find_another_user_with_same_email
        return true unless find_user
        return true if !identity_taken?(find_user) && !authorization_taken?(find_user)

        errors.add(
          :email,
          I18n.t("decidim.tunnistamo.email_confirmations.ask_email_form.errors.email_taken")
        )

        false
      end

      private

      def find_another_user_with_same_email
        find_user = Decidim::User.find_by(email: email, organization: current_organization)
        return find_user if find_user && find_user.id != current_user.id

        false
      end

      def identity_taken?(another_user_with_same_email)
        Decidim::Identity.find_by(provider: "tunnistamo", user: another_user_with_same_email).present?
      end

      def authorization_taken?(another_user_with_same_email)
        Decidim::Authorization.find_by(name: "tunnistamo_idp", user: another_user_with_same_email).present?
      end
    end
  end
end
