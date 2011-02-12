gem 'rack-rewrite'
require 'rack-rewrite'
use Rack::Rewrite do
  rewrite '/', '/index.html'
end

use Rack::Static, :urls => ['/', '/rb', '/css', '/images', '/favicon.ico'], :root => 'public'
use Rack::CommonLogger

