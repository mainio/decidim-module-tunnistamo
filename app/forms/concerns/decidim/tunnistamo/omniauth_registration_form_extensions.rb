# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module OmniauthRegistrationFormExtensions
      extend ActiveSupport::Concern

      included do
        attribute :email_confirmed, Virtus::Attribute::Boolean, default: true
        attribute :unconfirmed_email, String, default: ""
      end
    end
  end
end
