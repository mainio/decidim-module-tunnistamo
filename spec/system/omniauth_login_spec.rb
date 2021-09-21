# frozen_string_literal: true

require "spec_helper"

describe "Omniauth login", type: :system do
  let(:organization) { create(:organization) }

  context "when omniauth login" do
    let(:omniauth_hash) do
      OmniAuth::AuthHash.new(
        provider: :tunnistamo,
        uid: "123545",
        info: {
          email: email,
          name: tunnistamo_user_name
        }
      )
    end
    let(:tunnistamo_user_name) { "Tunnistamo User" }
    let(:email) { ::Faker::Internet.email }

    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:tunnistamo] = omniauth_hash
      switch_to_host(organization.host)
      visit decidim.root_path
    end

    context "when confirm emails is not enabled" do
      it "confirms user without email verification process" do
        tunnistamo_login
        visit decidim.account_path
        expect(page).to have_field("user_email", with: email)
        expect(Decidim::User.count).to eq(1)
        expect(Decidim::User.find_by(email: email).confirmed_at).to be_between(1.minute.ago, Time.current)
      end
    end

    context "when confirm emails is set to true" do
      before do
        allow(Decidim::Tunnistamo).to receive(:confirm_emails).and_return(true)
      end

      context "when there is another identity" do
        let!(:identity) { create(:identity, user: another_user, provider: "tunnistamo", organization: organization) }
        let(:another_user) { create(:user, :confirmed, organization: organization, email: another_email) }
        let(:another_email) { ::Faker::Internet.unique.email }

        context "and another tunnistamo identity has taken email already" do
          let(:another_email) { email }

          before { tunnistamo_login }

          describe "verificaition of email address" do
            before do
              click_button "Send verification code"
            end

            it "shows that email is already taken" do
              expect(page).to have_content("The email address you entered is already marked for another user on this service. Please use a different email address or contact the service administrators")
            end
          end
        end

        it "adds another identity and verifies email normally" do
          tunnistamo_login
          expect(Decidim::User.last.confirmed_at).to eq(nil)
          click_button "Send verification code"
          fill_in :code_confirmation_code, with: code_from_email
          click_button "Verify the email address"
          expect(page).to have_content("Email successfully confirmed")
          expect(Decidim::User.count).to eq(2)
          confirmed_user = Decidim::User.last
          expect(confirmed_user.email).to eq(email)
          expect(confirmed_user.tunnistamo_email_sent_to).to eq(email)
          expect(confirmed_user.confirmed_at).to be_between(1.minute.ago, Time.current)
          expect(Decidim::Identity.count).to eq(2)
        end
      end

      context "and there is another tunnistamo authorization already" do
        let!(:authorization) { create(:authorization, name: "tunnistamo_idp", user: another_user, organization: organization) }
        let(:another_user) { create(:user, :confirmed, organization: organization, email: another_email) }
        let(:another_email) { ::Faker::Internet.unique.email }

        before { tunnistamo_login }

        context "when another user with tunnistamo authorization has same email" do
          let(:another_email) { email }

          describe "verificaition of email address" do
            before do
              click_button "Send verification code"
            end

            it "shows that email is already taken" do
              expect(page).to have_content("The email address you entered is already marked for another user on this service. Please use a different email address or contact the service administrators")
            end
          end
        end

        it "adds another authorization and verifies email normally" do
          expect(Decidim::User.last.confirmed_at).to eq(nil)
          click_button "Send verification code"
          fill_in :code_confirmation_code, with: code_from_email
          click_button "Verify the email address"
          expect(page).to have_content("Email successfully confirmed")
          expect(Decidim::User.count).to eq(2)
          confirmed_user = Decidim::User.last
          expect(confirmed_user.email).to eq(email)
          expect(confirmed_user.tunnistamo_email_sent_to).to eq(email)
          expect(confirmed_user.confirmed_at).to be_between(1.minute.ago, Time.current)
          expect(Decidim::Authorization.count).to eq(2)
        end
      end

      describe "accepting tos agreement and double authentication" do
        before do
          tunnistamo_login
          click_link tunnistamo_user_name
          click_link "Sign out"
          click_link "Sign In"
          click_link "Sign in with Tunnistamo"
        end

        it "doesnt confirm user" do
          expect(page).to have_content("Successfully authenticated from Tunnistamo account")
          expect(Decidim::User.last.tos_accepted?).to eq(true)
          expect(Decidim::User.last.confirmed_at).to eq(nil)
        end
      end

      describe "redirects before sign in path after sign in" do
        let!(:participatory_process) { create(:participatory_process, organization: organization) }
        let(:process_path) { decidim_participatory_processes.participatory_process_path(participatory_process.slug) }

        before do
          visit process_path
          tunnistamo_login
        end

        after do
          expect(page).to have_content("Email successfully confirmed")
          expect(page).to have_current_path process_path
          user = Decidim::User.find_by(email: email)
          expect(user.confirmed_at).to be_between(1.minute.ago, Time.current)
        end

        it "submitting the code" do
          click_button "Send verification code"
          fill_in :code_confirmation_code, with: code_from_email
          click_button "Verify the email address"
        end

        it "cliking email link" do
          click_button "Send verification code"
          visit last_email_first_link
        end
      end
    end
  end

  def tunnistamo_login
    click_link "Sign In"
    click_link "Sign in with Tunnistamo"
    click_button "I agree with these terms"
  end

  def code_from_email
    content = Nokogiri::HTML(last_email_body).css("div#code").first.children.first.content
    content.scan(/\d+/).first
  end
end
