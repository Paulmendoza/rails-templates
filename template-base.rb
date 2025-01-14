gem 'devise'
run 'bundle install'
generate "devise:install"
generate "devise:views"
gem 'omniauth'
gem 'omniauth-rails_csrf_protection'
gem 'omniauth-facebook'
gem 'omniauth-google-oauth2'
run 'bundle install'
generate "devise", "user"
inject_into_file "config/routes.rb", after: "devise_for :users" do <<-RUBY
, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }
RUBY
end
inject_into_file "app/models/user.rb", before: "end" do <<-RUBY
  devise :omniauthable, omniauth_providers: [:google_oauth2, :facebook]

  def self.from_omniauth(access_token)
    user = User.where(email: access_token.info.email).first

    user ||= User.create!(provider: access_token.provider, uid: access_token.uid, email: access_token.info.email, password: Devise.friendly_token[0, 20])
    user
  end
RUBY
end

generate :migration, "AddOmniauthToUsers", "provider:string", "uid:string"
rails_command 'db:migrate'

inject_into_file "config/initializers/devise.rb", after: "# ==> OmniAuth\n" do <<-CODE
  config.omniauth :facebook, ENV["FACEBOOK_APP_ID"], ENV["FACEBOOK_APP_SECRET"], {scope: 'email'}
  config.omniauth :google_oauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET'], {scope: 'email', prompt: 'select_account'}
CODE
end

inject_into_file "app/views/layouts/application.html.erb", after: "<body>\n" do <<-CODE
  <p class="notice"><%= notice %></p>
  <p class="alert"><%= alert %></p>
CODE
end

generate :controller, "home", "index"

append_file  "app/views/home/index.html.erb", <<-CODE
<%= button_to "Register with Facebook", user_facebook_omniauth_authorize_path, method: :post, data: { turbo: 'false' }  %>
<%= button_to "Register with Google", user_google_oauth2_omniauth_authorize_path, method: :post, data: { turbo: 'false' } %>
CODE

route "root to: 'home#index'"

generate "devise:controllers", "users", "-c=omniauth_callbacks"

route "devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }"

inject_into_file "app/controllers/users/omniauth_callbacks_controller.rb", before: "\n  # You should also create an action method in this controller like this:" do <<-CODE
  def google_oauth2
    @user = User.from_omniauth(request.env['omniauth.auth'])

    if @user.persisted?
      sign_in_and_redirect @user
    else
      session['devise.google_data'] = request.env['omniauth.auth'].except(:extra) # Removing extra as it can overflow some session stores
      redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
    end
  end

  def facebook
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication #this will throw if @user is not activated
      set_flash_message(:notice, :success, kind: "Facebook") if is_navigational_format?
    else
      session["devise.facebook_data"] = request.env["omniauth.auth"].except(:extra) # Removing extra as it can overflow some session stores
      redirect_to new_user_registration_url
    end
  end

  def failure
    redirect_to root_path
  end
CODE
end

file ".devcontainer/devcontainer.json", <<-JSON
  {
  "build": { "dockerfile": "Dockerfile" },
  "remoteUser": "vscode",
  "appPort": ["3000:3000"],
  "features": {
    "ghcr.io/rails/devcontainer/features/activestorage": {}
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "ninoseki.vscode-mogami",
        "bradlc.vscode-tailwindcss",
        "will-wow.vscode-alternate-file",
        "setobiralo.erb-commenter",
        "ms-azuretools.vscode-docker"
      ]
    }
  },
  "runArgs": ["--env-file", "${localWorkspaceFolder}/.devcontainer/devcontainer.env"]
}
JSON

file ".devcontainer/Dockerfile", <<-Dockerfile
FROM ghcr.io/rails/devcontainer/images/ruby:3.3.6
RUN sudo apt-get update && sudo apt-get -y install libpq-dev
Dockerfile

file ".devcontainer/devcontainer.env", <<-ENV
POSTGRESQL_LOC=
FACEBOOK_APP_ID=
FACEBOOK_APP_SECRET=
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
ENV