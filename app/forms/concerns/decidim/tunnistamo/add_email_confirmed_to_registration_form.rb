# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module AddEmailConfirmedToRegistrationForm
      extend ActiveSupport::Concern

      included do
        attribute :email_confirmed, Virtus::Attribute::Boolean, default: true
        attribute :unconfirmed_email, String, default: ""
      end
    end
  end
end
