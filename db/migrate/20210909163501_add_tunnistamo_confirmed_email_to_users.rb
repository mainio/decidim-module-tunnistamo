# frozen_string_literal: true

class AddTunnistamoConfirmedEmailToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :decidim_users, :tunnistamo_email_confirmed_at, :datetime, default: nil
    add_column :decidim_users, :tunnistamo_email_sent_to, :string, default: nil
    add_column :decidim_users, :tunnistamo_email_code, :string, default: nil
    add_column :decidim_users, :tunnistamo_email_code_sent_at, :datetime, default: nil
  end
end
