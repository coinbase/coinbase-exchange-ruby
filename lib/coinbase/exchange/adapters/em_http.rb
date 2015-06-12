module Coinbase
  module Exchange
    # EM-Http Adapter
    class EMHTTPClient < APIClient
      def initialize(api_key, api_secret, api_pass, options = {})
        super(api_key, api_secret, api_pass, options)
      end

      private

      def http_verb(method, path, body = nil)
        if !EventMachine.reactor_running?
          EM.run do
            # FIXME: This doesn't work with paginated endpoints
            http_verb(method, path, body) do |resp|
              yield(resp)
              EM.stop
            end
          end
        else
          req_ts = Time.now.utc.to_i.to_s
          signature = Base64.encode64(
            OpenSSL::HMAC.digest('sha256', Base64.decode64(@api_secret).strip,
                                 "#{req_ts}#{method}#{path}#{body}")).strip
          headers = {}
          headers['Content-Type'] = 'application/json'
          headers['CB-ACCESS-TIMESTAMP'] = req_ts
          headers['CB-ACCESS-PASSPHRASE'] = @api_pass
          headers['CB-ACCESS-KEY'] = @api_key
          headers['CB-ACCESS-SIGN'] = signature

          case method
          when 'GET'
            req = EM::HttpRequest.new(@api_uri).get(path: path, head: headers, body: body)
          when 'POST'
            req = EM::HttpRequest.new(@api_uri).post(path: path, head: headers, body: body)
          when 'DELETE'
            req = EM::HttpRequest.new(@api_uri).delete(path: path, head: headers)
          else fail
          end
          req.callback do |resp|
            case resp.response_header.status
            when 200 then yield(EMHTTPResponse.new(resp))
            when 400 then fail BadRequestError, resp.response
            when 401 then fail NotAuthorizedError, resp.response
            when 403 then fail ForbiddenError, resp.response
            when 404 then fail NotFoundError, resp.response
            when 429 then fail RateLimitError, resp.response
            when 500 then fail InternalServerError, resp.response
            end
          end
          req.errback do |resp|
            fail APIError, "#{method} #{@api_uri}#{path}: #{resp.error}"
          end
        end
      end
    end

    # EM-Http response object
    class EMHTTPResponse < APIResponse
      def body
        @response.response
      end

      def headers
        out = @response.response_header.map do |key, val|
          [ key.upcase.gsub('_', '-'), val ]
        end
        out.to_h
      end

      def status
        @response.response_header.status
      end
    end
  end
end
