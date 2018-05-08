require "json"
require "uri"
require "net/http"
require "em-http-request"
require "faye/websocket"

require "coinbase/exchange/errors"
require "coinbase/exchange/api_object"
require "coinbase/exchange/api_response"
require "coinbase/exchange/api_client.rb"
require "coinbase/exchange/adapters/net_http.rb"
require "coinbase/exchange/adapters/em_http.rb"
require "coinbase/exchange/client"
require "coinbase/exchange/websocket"

module Coinbase
  # Coinbase Exchange module
  module Exchange
  end
end
