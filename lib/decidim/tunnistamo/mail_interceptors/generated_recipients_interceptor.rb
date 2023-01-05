# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module MailInterceptors
      # Prevents sending emails to the auto-generated email addresses.
      class GeneratedRecipientsInterceptor
        def self.delivering_email(message)
          return unless email_domain

          # Regexp to match the auto-generated emails
          regexp = /^tunnistamo-[a-z0-9]{32}@#{email_domain}$/

          # Remove the auto-generated email from the message recipients
          message.to = message.to.grep_v(regexp) if message.to
          message.cc = message.cc.grep_v(regexp) if message.cc
          message.bcc = message.bcc.grep_v(regexp) if message.bcc

          # Prevent delivery in case there are no recipients on the email
          message.perform_deliveries = false if message.to.empty?
        end

        def self.email_domain
          @email_domain ||= if Decidim::Tunnistamo.auto_email_domain
                              Decidim::Tunnistamo.auto_email_domain
                            else
                              conf = Rails.application.config
                              url_options = conf.action_controller.default_url_options
                              url_options = conf.action_mailer.default_url_options if !url_options || !url_options[:host]
                              url_options ||= {}

                              url_options[:host]
                            end
        end
      end
    end
  end
end
