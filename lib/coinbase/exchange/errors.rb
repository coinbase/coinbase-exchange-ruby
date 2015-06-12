module Coinbase
  module Exchange
    #
    # Websocket Errors
    #
    class WebsocketError < RuntimeError
    end

    class DroppedPackets < WebsocketError
    end

    #
    # Rest API Errors
    #
    class APIError < RuntimeError
    end

    # Status 400
    class BadRequestError < APIError
    end

    # Status 401
    class NotAuthorizedError < APIError
    end

    # Status 403
    class ForbiddenError < APIError
    end

    # Status 404
    class NotFoundError < APIError
    end

    # Status 429
    class RateLimitError < APIError
    end

    # Status 500
    class InternalServerError < APIError
    end
  end
end
