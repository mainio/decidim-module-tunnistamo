# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class AskEmailForm < Form
      attribute :email

      validates :email, presence: true, 'valid_email_2/email': { disposable: true }
    end
  end
end
