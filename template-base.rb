def source_paths
  Array(super) << [File.expand_path(File.dirname(__FILE__))]
end

# Devise
gem 'devise'
run 'bundle install'
generate "devise:install"
generate "devise:views"
generate "devise", "user"

# Omniauth
gem 'omniauth'
gem 'omniauth-rails_csrf_protection'
gem 'omniauth-facebook'
gem 'omniauth-google-oauth2'
run 'bundle install'

# Integrate Omniauth with Devise users
inject_into_file "app/models/user.rb", before: "end" do <<-RUBY
  devise :omniauthable, omniauth_providers: [:google_oauth2, :facebook]
  
  def self.from_omniauth(access_token)
    user = User.where(email: access_token.info.email).first
    
    user ||= User.create!(provider: access_token.provider, uid: access_token.uid, email: access_token.info.email, password: Devise.friendly_token[0, 20])
    user
  end
  RUBY
end

# Add Users::OmniauthCallbacksController
# Cleaned up version of what's generated with 'generate "devise:controllers", "users", "-c=omniauth_callbacks"'
template "./omniauth-file-template/omniauth_callbacks_controller.rb", "app/controllers/users/omniauth_callbacks_controller.rb"

# Add Omniauth callback routes
gsub_file "config/routes.rb", "devise_for :users\n", "devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }\n"

generate :migration, "AddOmniauthToUsers", "provider:string", "uid:string"
rails_command 'db:migrate'

# Config Omniauth
inject_into_file "config/initializers/devise.rb", after: "# ==> OmniAuth\n" do <<-CODE
  config.omniauth :facebook, ENV["FACEBOOK_APP_ID"], ENV["FACEBOOK_APP_SECRET"], {scope: 'email'}
  config.omniauth :google_oauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET'], {scope: 'email', prompt: 'select_account'}
CODE
end

# Add links to main layout
inject_into_file "app/views/layouts/application.html.erb", after: "<body>\n" do <<-CODE
  <nav>
    <%= link_to "Home", root_path %>
    <%= link_to "Sign In", new_user_session_path %>
    <%= link_to "Sign Up", new_user_registration_path %>
  </nav>
  <p class="notice"><%= notice %></p>
  <p class="alert"><%= alert %></p>
CODE
end

# Add Home page
generate :controller, "home", "index"
route "root to: 'home#index'"

# Add devcontainer files
directory "./devcontainer-template", ".devcontainer"

after_bundle do
  git add: ".", commit: %(-m 'init.')
end