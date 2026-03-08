# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: "Prowl <alerts@prowl.lucyapps.com>"
  layout "mailer"
end
