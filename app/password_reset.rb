get '/password_reset' do
  redirect '/' if signed_in?
  erb :'password_reset'
end

post '/send_password_reset' do
  if params[:email].blank?
    flash[:error] = 'You must enter a valid email address.'
    redirect '/password_reset'
  end

  sites = Site.filter(email: params[:email]).all

  if sites.length > 0
    token = SecureRandom.uuid.gsub('-', '')
    sites.each do |site|
      next unless site.parent?
      site.update password_reset_token: token

      body = <<-EOT
Hello! This is the Neocities cat, and I have received a password reset request for your e-mail address.

Go to this URL to reset your password: http://neocities.org/password_reset_confirm?username=#{Rack::Utils.escape(site.username)}&token=#{token}

If you didn't request this password reset, you can ignore it. Or hide under a bed. Or take a nap. Your call.

Meow,
the Neocities Cat
    EOT

      body.strip!

      EmailWorker.perform_async({
        from: 'web@neocities.org',
        to: params[:email],
        subject: '[Neocities] Password Reset',
        body: body
      })

    end
  end

  flash[:success] = 'If your email was valid (and used by a site), the Neocities Cat will send an e-mail to your account with password reset instructions.'
  redirect '/'
end

get '/password_reset_confirm' do
  if params[:token].nil? || params[:token].strip.empty?
    flash[:error] = 'Token cannot be empty.'
    redirect '/'
  end

  reset_site = Site.where(username: params[:username], password_reset_token: params[:token]).first

  if reset_site.nil?
    flash[:error] = 'Could not find a site with this username and token.'
    redirect '/'
  end

  reset_site.password_reset_token = nil
  reset_site.password_reset_confirmed = true
  reset_site.save_changes

  session[:id] = reset_site.id

  redirect '/settings#password'
end
