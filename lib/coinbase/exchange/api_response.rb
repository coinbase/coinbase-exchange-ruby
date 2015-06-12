module Coinbase
  module Exchange
    # Encapsulate data for an API response
    class APIResponse
      attr_reader :received_at

      def initialize(resp)
        @received_at = Time.now
        @response = resp
      end

      def raw
        @response
      end

      def body
        fail NotImplementedError
      end

      def headers
        fail NotImplementedError
      end

      def status
        fail NotImplementedError
      end
    end
  end
end
