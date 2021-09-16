# frozen_string_literal: true

require "spec_helper"

describe "Omniauth login", type: :system do
  let(:organization) { create(:organization) }

  before do
    allow(Decidim::Tunnistamo).to receive(:confirm_emails).and_return(true)
  end

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
    let(:email) { "user@from-tunnistamo.com" }

    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:tunnistamo] = omniauth_hash
      switch_to_host(organization.host)
      visit decidim.root_path
    end

    describe "accepting tos agreement and double authentication" do
      before do
        click_link "Sign In"
        click_link "Sign in with Tunnistamo"
        click_button "I agree with these terms"
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
        click_link "Sign In"
        click_link "Sign in with Tunnistamo"
        click_button "I agree with these terms"
      end

      after do
        expect(page).to have_content("#{email} successfully confirmed")
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

  def code_from_email
    content = Nokogiri::HTML(last_email_body).css("div#code").first.children.first.content
    content.scan(/\d+/).first
  end
end
