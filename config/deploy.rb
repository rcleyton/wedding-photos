lock "~> 3.20.1"

set :application, "wedding_photos"
set :repo_url, "git@github.com:rcleyton/wedding-photos.git"
set :deploy_to, "/var/www/wedding_photos"

set :rvm_ruby_version, "ruby-4.0.5@wedding_photos"

set :keep_releases, 5

append :linked_files, ".env"

append :linked_dirs,
  "log",
  "tmp/pids",
  "tmp/cache",
  "tmp/sockets"
