# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class EmailConfirmationsController < Decidim::ApplicationController
      include Decidim::FormFactory

      # before_action :user_logged?, expect: [:confirm_with_token]
      # before_action :user_confirmed? TODO: Redirect out from here if user is already confirmed

      skip_before_action :store_current_location, :tunnistamo_email_confirmed

      def new
        @form = ::Decidim::Tunnistamo::EmailConfirmationForm.new(email: current_user.unconfirmed_email)
      end

      def create
        @form = form(::Decidim::Tunnistamo::EmailConfirmationForm).from_params(params)

        ::Decidim::Tunnistamo::CreateEmailConfirmation.call(@form, current_user) do
          on(:ok) do
            redirect_to preview_email_confirmation_path, email: @form.email
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
          on(:ok) do |confirmed_email|
            flash[:notice] = t("decidim.tunnistamo.email_confirmations.complete.success", email: confirmed_email)
            redirect_to after_sign_in_path_for current_user
          end

          on(:invalid) do
            flash.now[:alert] = t("decidim.tunnistamo.email_confirmations.complete.invalid")
            redirect_to new_email_confirmation_path
          end
        end
      end

      def complete
        @form = form(::Decidim::Tunnistamo::CodeConfirmationForm).from_params(params)

        ::Decidim::Tunnistamo::ConfirmCode.call(@form, current_user) do
          on(:ok) do |confirmed_email|
            flash[:notice] = t("decidim.tunnistamo.email_confirmations.complete.success", email: confirmed_email)
            redirect_to decidim.root_path
          end

          on(:invalid) do
            flash.now[:alert] = t("decidim.tunnistamo.email_confirmations.complete.invalid")
            render :preview
          end
        end
      end

      private

      def user_logged?
        redirect_to decidim.root_path unless current_user
      end
    end
  end
end
