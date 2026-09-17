server "64.227.52.217",
  user: "deploy",
  roles: %w[app web db],
  primary: true

set :branch, "main"
set :rails_env, "production"
set :rvm_ruby_version, "ruby-4.0.5@wedding_photos"
