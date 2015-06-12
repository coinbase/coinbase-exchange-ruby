module Coinbase
  module Exchange
    class Client < NetHTTPClient
    end

    class AsyncClient < EMHTTPClient
    end
  end
end
