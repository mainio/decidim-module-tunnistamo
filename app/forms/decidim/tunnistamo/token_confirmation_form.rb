# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class TokenConfirmationForm < Form
      attribute :user_id
      attribute :confirmation_token

      validates :confirmation_token, presence: true
      validates :user, presence: true

      def user
        @user ||= Decidim::User.find_by(
          id: user_id,
          organization: current_organization
        )
      end
    end
  end
end
