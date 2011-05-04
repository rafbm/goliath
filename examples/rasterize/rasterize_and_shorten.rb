#!/usr/bin/env ruby
$: << File.dirname(__FILE__)+'/../../lib'
require File.dirname(__FILE__)+'/rasterize'

require 'goliath'
require 'em-synchrony/em-http'
require 'postrank-uri'

#
# Aroundware: while the Rasterize API is processing, this uses http://is.gd to
# generate a shortened link, stuffing it in the header. Both requests happen
# simultaneously.
#
class ShortenURL < Goliath::Synchrony::MultiReceiver
  SHORTENER_URL_BASE = 'http://is.gd/create.php'

  def shortener_req
    target_url = PostRank::URI.clean(env.params['url'])
    EM::HttpRequest.new(SHORTENER_URL_BASE).aget(:query => { :format => 'simple', :url => target_url })
  end

  def pre_process
    add :shortener, shortener_req
  end

  def post_process
    if responses[:callback][:shortener]
      headers['X-Shortened-URI'] = responses[:callback][:shortener].response
    end
    [status, headers, body]
  end
end

class RasterizeAndShorten < Rasterize
  use Goliath::Rack::Params
  use Goliath::Rack::Validation::RequestMethod, %w(GET)
  use Goliath::Rack::Validation::RequiredParam, {:key => 'url'}
  #
  use Goliath::Rack::AsyncAroundware, ShortenURL
end
