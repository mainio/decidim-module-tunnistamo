# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class EmailConfirmationsController < Decidim::ApplicationController
      include Decidim::FormFactory

      before_action :authenticate_user!, except: [:confirm_with_token]
      before_action :user_confirmed?

      skip_before_action :store_current_location, :tunnistamo_email_confirmed

      default_form_builder Decidim::Tunnistamo::FormBuilder

      def new
        @form = ::Decidim::Tunnistamo::AskEmailForm.new(email: unverified_email)
      end

      def create
        @form = form(::Decidim::Tunnistamo::AskEmailForm).from_params(params)

        ::Decidim::Tunnistamo::SendConfirmationEmail.call(@form, current_user) do
          on(:ok) do
            flash[:notice] = t("decidim.tunnistamo.email_confirmations.create.success")
            redirect_to preview_email_confirmations_path, email: @form.email
          end

          on(:invalid) do
            flash.now[:alert] = t("decidim.tunnistamo.email_confirmations.create.invalid")
            render :new
          end
        end
      end

      def preview
        @form = form(::Decidim::Tunnistamo::CodeConfirmationForm).from_params(params)
        render :preview
      end

      def confirm_with_token
        @form = form(::Decidim::Tunnistamo::TokenConfirmationForm).from_params(params)

        ::Decidim::Tunnistamo::ConfirmToken.call(@form) do
          on(:ok) do
            flash[:notice] = t("decidim.tunnistamo.email_confirmations.confirm_with_token.success")
            redirect_to after_sign_in_path_for current_user || Decidim::User
          end

          on(:invalid) do
            flash.now[:alert] = t("decidim.tunnistamo.email_confirmations.confirm_with_token.invalid")
            redirect_to new_email_confirmation_path
          end
        end
      end

      def confirm_with_code
        @form = form(::Decidim::Tunnistamo::CodeConfirmationForm).from_params(params)

        ::Decidim::Tunnistamo::ConfirmCode.call(@form, current_user) do
          on(:ok) do
            flash[:notice] = t("decidim.tunnistamo.email_confirmations.confirm_with_code.success")
            redirect_to after_sign_in_path_for current_user
          end

          on(:invalid) do
            flash.now[:alert] = t("decidim.tunnistamo.email_confirmations.confirm_with_code.invalid")
            render :preview
          end
        end
      end

      private

      def unverified_email
        @unverified_email ||= begin
          email = current_user.unconfirmed_email || current_user.email
          if email.match?(/tunnistamo-(\w+)@#{current_organization.host}/)
            nil
          else
            email
          end
        end
      end

      def user_confirmed?
        redirect_to decidim.root_path if current_user&.confirmed_at
      end
    end
  end
end
