# frozen_string_literal: true

require "spec_helper"

describe "Email confirmation", type: :system do
  let(:organization) { create(:organization) }
  let(:current_user) { create(:user, unconfirmed_email: unconfirmed_email, organization: organization) }
  let(:unconfirmed_email) { Faker::Internet.email }

  before do
    allow(Decidim::Tunnistamo).to receive(:confirm_emails).and_return(true)
  end

  context "when user is logged in" do
    let!(:identity) { create(:identity, user: current_user, provider: "tunnistamo", uid: SecureRandom.uuid) }
    let!(:authorization) { Decidim::Authorization.create(name: "tunnistamo_idp", user: current_user, granted_at: Time.current) }

    before do
      switch_to_host(organization.host)
      login_as current_user, scope: :user
      visit decidim.root_path
    end

    # Action mailer test helpers: decidim-dev/lib/decidim/dev/test/rspec_support/action_mailer.rb
    describe "email address from tunnistamo" do
      it "verifies email address" do
        click_button "Send verification code"
        fill_in :code_confirmation_code, with: code_from_email
        click_button "Verify the email address"
        expect(page).to have_content("Email successfully confirmed")
        confirmed_user = Decidim::User.find(current_user.id)
        expect(confirmed_user.email).to eq(unconfirmed_email)
        expect(confirmed_user.tunnistamo_email_sent_to).to eq(unconfirmed_email)
        expect(confirmed_user.confirmed_at).to be_between(1.minute.ago, Time.current)
      end
    end

    describe "invalid code" do
      let(:wrong_code) do
        six_digits = "%06d"
        invalid_code = format(six_digits, rand(0..999_999))
        invalid_code = format(six_digits, rand(0..999_999)) while invalid_code == code_from_email
        invalid_code
      end

      it "doesnt verify the user" do
        click_button "Send verification code"
        fill_in :code_confirmation_code, with: wrong_code
        click_button "Verify the email address"
        expect(page).to have_content("Couldn't confirm email")
        find_user = Decidim::User.find(current_user.id)
        expect(find_user.confirmed_at).to eq(nil)
        expect(find_user.tunnistamo_failed_confirmation_attempts).to eq(1)
        expect(page).not_to have_content("Maximum attempts reached. Please go to previous step and re-enter your email")
      end

      it "reaches maximum attempts" do
        click_button "Send verification code"
        21.times.each do
          fill_in :code_confirmation_code, with: wrong_code
          click_button "Verify the email address"
        end
        expect(page).to have_content("Maximum attempts reached. Please go to previous step and re-enter your email")
        find_user = Decidim::User.find(current_user.id)
        expect(find_user.confirmed_at).to eq(nil)
      end
    end

    describe "change email" do
      let(:change_email) { Faker::Internet.email }

      it "verifies new email address" do
        fill_in :ask_email_email, with: change_email
        click_button "Send verification code"
        fill_in :code_confirmation_code, with: code_from_email
        click_button "Verify the email address"
        expect(page).to have_content("Email successfully confirmed")
        confirmed_user = Decidim::User.find(current_user.id)
        expect(confirmed_user.email).to eq(change_email)
        expect(confirmed_user.tunnistamo_email_sent_to).to eq(change_email)
        expect(confirmed_user.confirmed_at).to be_between(1.minute.ago, Time.current)
      end
    end

    describe "confirm another users email" do
      let!(:existing_user) { create(:user, email: reserved_email, organization: organization) }
      let(:reserved_email) { ::Faker::Internet.unique.email }

      it "deletes current user and logins as existing user" do
        fill_in :ask_email_email, with: reserved_email
        click_button "Send verification code"
        fill_in :code_confirmation_code, with: code_from_email
        click_button "Verify the email address"
        expect(page).to have_content("Email successfully confirmed")
        expect(Decidim::User.where(id: current_user).count).to eq(0)
        expect(Decidim::User.count).to eq(1)
        expect(Decidim::User.last.email).to eq(reserved_email)
      end
    end

    describe "email verification link" do
      it "verifies email" do
        click_button "Send verification code"
        visit last_email_first_link
        expect(page).to have_content("Email successfully confirmed")
        find_user = Decidim::User.find(current_user.id)
        expect(find_user.confirmed_at).to be_between(1.minute.ago, Time.current)
        expect(find_user.email).to eq(unconfirmed_email)
      end
    end

    context "and confirmed" do
      let(:current_user) { create(:user, :confirmed, organization: organization) }

      describe "email confirmation paths redirects to root path" do
        after do
          expect(page).to have_current_path decidim.root_path
        end

        it "redirects from new" do
          visit decidim_tunnistamo.new_email_confirmation_path
        end

        it "fedirects from preview" do
          visit decidim_tunnistamo.preview_email_confirmations_path
        end
      end
    end
  end

  context "when user is not logged" do
    before do
      switch_to_host(organization.host)
    end

    describe "redirect to sign in path" do
      after do
        expect(page).to have_content("You need to sign in or sign up before continuing")
        expect(page).to have_current_path decidim.new_user_session_path
      end

      it "new redirects" do
        visit decidim_tunnistamo.new_email_confirmation_path
      end

      it "preview redirects" do
        visit decidim_tunnistamo.preview_email_confirmations_path
      end
    end
  end

  def code_from_email
    content = Nokogiri::HTML(last_email_body).css("div#code").first.children.first.content
    content.scan(/\d+/).first
  end
end
