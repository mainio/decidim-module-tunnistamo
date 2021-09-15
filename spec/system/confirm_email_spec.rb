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
    let!(:identity) { create(:identity, user: current_user, provider: "tunnistamo", uid: "12345") }
    let!(:authorization) { Decidim::Authorization.create(name: "tunnistamo_idp", user: current_user, granted_at: Time.current) }

    before do
      switch_to_host(organization.host)
      login_as current_user, scope: :user
      visit decidim.root_path
    end

    # Action mailer test helpers: decidim-dev/lib/decidim/dev/test/rspec_support/action_mailer.rb
    describe "unchanged email" do
      it "verifies email address" do
        click_button "Send verification code"
        fill_in :code_confirmation_code, with: code_from_email
        click_button "Verify the email address"
        expect(page).to have_content("#{unconfirmed_email} successfully confirmed")
        confirmed_user = Decidim::User.find(current_user.id)
        expect(confirmed_user.tunnistamo_email_sent_to).to eq(unconfirmed_email)
        expect(confirmed_user.confirmed_at).to be_between(1.minute.ago, Time.current)
      end
    end

    describe "change email" do
      let(:change_email) { Faker::Internet.email }

      it "verifies new email address" do
        fill_in :email_confirmation_email, with: change_email
        click_button "Send verification code"
        fill_in :code_confirmation_code, with: code_from_email
        click_button "Verify the email address"
        expect(page).to have_content("#{change_email} successfully confirmed")
        confirmed_user = Decidim::User.find(current_user.id)
        expect(confirmed_user.tunnistamo_email_sent_to).to eq(change_email)
        expect(confirmed_user.confirmed_at).to be_between(1.minute.ago, Time.current)
      end
    end

    describe "confirm another users email" do
      let!(:existing_user) { create(:user, email: reserved_email, organization: organization) }
      let(:reserved_email) { "tunnistamo@example.org" }

      it "deletes current user and logins as existing user" do
        fill_in :email_confirmation_email, with: reserved_email
        click_button "Send verification code"
        fill_in :code_confirmation_code, with: code_from_email
        click_button "Verify the email address"
        expect(page).to have_content("#{reserved_email} successfully confirmed")
        expect(Decidim::User.where(id: current_user).count).to eq(0)
        expect(Decidim::User.count).to eq(1)
      end
    end

    describe "email verification link" do
      it "verifies email" do
        click_button "Send verification code"
        visit last_email_first_link
        expect(page).to have_content("#{unconfirmed_email} successfully confirmed")
        find_user = Decidim::User.find(current_user.id)
        expect(find_user.confirmed_at).to be_between(1.minute.ago, Time.current)
      end
    end
  end

  def code_from_email
    content = Nokogiri::HTML(last_email_body).css("div#code").first.children.first.content
    content.scan(/\d+/).first
  end
end
