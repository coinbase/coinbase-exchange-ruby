module Coinbase
  module Exchange
    # Net-http client for Coinbase Exchange API
    class APIClient
      def initialize(api_key = '', api_secret = '', api_pass = '', options = {})
        @api_uri = URI.parse(options[:api_url] || "https://api.exchange.coinbase.com")
        @api_pass = api_pass
        @api_key = api_key
        @api_secret = api_secret
        @default_product = options[:product_id] || "BTC-USD"
      end

      def server_epoch(params = {})
        get("/time", params) do |resp|
          yield(resp) if block_given?
        end
      end

      #
      # Market Data
      #
      def currencies(params = {})
        out = nil
        get("/currencies", params) do |resp|
          out = response_collection(resp)
          yield(out, resp) if block_given?
        end
        out
      end

      def products(params = {})
        out = nil
        get("/products", params) do |resp|
          out = response_collection(resp)
          yield(out, resp) if block_given?
        end
        out
      end

      def orderbook(params = {})
        product = params[:product_id] || @default_product
        
        out = nil
        get("/products/#{product}/book", params) do |resp|
          out = response_object(resp)
          yield(out, resp) if block_given?
        end
        out
      end

      def last_trade(params = {})
        product = params[:product_id] || @default_product
        
        out = nil
        get("/products/#{product}/ticker", params) do |resp|
          out = response_object(resp)
          yield(out, resp) if block_given?
        end
        out
      end

      def trade_history(params = {})
        product = params[:product_id] || @default_product
        
        out = nil
        get("/products/#{product}/trades", params, paginate: true) do |resp|
          out = response_collection(resp)
          yield(out, resp) if block_given?
        end
        out
      end

      def price_history(params = {})
        product = params[:product_id] || @default_product
        
        out = nil
        get("/products/#{product}/candles", params) do |resp|
          out = response_collection(
            resp.map do |item|
              { 'start' => Time.at(item[0]),
                'low' => item[1],
                'high' => item[2],
                'open' => item[3],
                'close' => item[4],
                'volume' => item[5]
              }
            end
          )
          yield(out, resp) if block_given?
        end
        out
      end

      def daily_stats(params = {})
        product = params[:product_id] || @default_product
        
        out = nil
        get("/products/#{product}/stats", params) do |resp|
          resp["start"] = (Time.now - 24 * 60 * 60).to_s
          out = response_object(resp)
          yield(out, resp) if block_given?
        end
        out
      end

      #
      # Accounts
      #
      def accounts(params = {})
        out = nil
        get("/accounts", params) do |resp|
          out = response_collection(resp)
          yield(out, resp) if block_given?
        end
        out
      end

      def account(id, params = {})
        out = nil
        get("/accounts/#{id}", params) do |resp|
          out = response_object(resp)
          yield(out, resp) if block_given?
        end
        out
      end

      def account_history(id, params = {})
        out = nil
        get("/accounts/#{id}/ledger", params, paginate: true) do |resp|
          out = response_collection(resp)
          yield(out, resp) if block_given?
        end
        out
      end

      def account_holds(id, params = {})
        out = nil
        get("/accounts/#{id}/holds", params, paginate: true) do |resp|
          out = response_collection(resp)
          yield(out, resp) if block_given?
        end
        out
      end

      #
      # Orders
      #
      def bid(amt, price, params = {})
        params[:product_id] ||= @default_product
        params[:size] = amt
        params[:price] = price
        params[:side] = "buy"
        
        out = nil
        post("/orders", params) do |resp|
          out = response_object(resp)
          yield(out, resp) if block_given?
        end
        out
      end
      alias_method :buy, :bid

      def ask(amt, price, params = {})
        params[:product_id] ||= @default_product
        params[:size] = amt
        params[:price] = price
        params[:side] = "sell"

        out = nil
        post("/orders", params) do |resp|
          out = response_object(resp)
          yield(out, resp) if block_given?
        end
        out
      end
      alias_method :sell, :ask

      def cancel(id)
        out = nil
        delete("/orders/#{id}") do |resp|
          out = response_object(resp)
          yield(out, resp) if block_given?
        end
        out
      end

      def orders(params = {})
        params[:status] ||= "all"
        
        out = nil
        get("/orders", params, paginate: true) do |resp|
          out = response_collection(resp)
          yield(out, resp) if block_given?
        end
        out
      end

      def order(id, params = {})
        out = nil
        get("/orders/#{id}", params) do |resp|
          out = response_object(resp)
          yield(out, resp) if block_given?
        end
        out
      end

      def fills(params = {})
        out = nil
        get("/fills", params, paginate: true) do |resp|
          out = response_collection(resp)
          yield(out, resp) if block_given?
        end
        out
      end

      #
      # Transfers
      #
      def deposit(account_id, amt, params = {})
        params[:type] = "deposit"
        params[:coinbase_account_id] = account_id
        params[:amount] = amt
        
        out = nil
        post("/transfers", params) do |resp|
          out = response_object(resp)
          yield(out, resp) if block_given?
        end
        out
      end

      def withdraw(account_id, amt, params = {})
        params[:type] = "withdraw"
        params[:coinbase_account_id] = account_id
        params[:amount] = amt

        out = nil
        post("/transfers", params) do |resp|
          out = response_object(resp)
          yield(out, resp) if block_given?
        end
        out
      end

      private

      def response_collection(resp)
        out = resp.map { |item| APIObject.new(item) }
        out.instance_eval { @response = resp.response }
        add_metadata(out)
        out
      end

      def response_object(resp)
        out = APIObject.new(resp)
        out.instance_eval { @response = resp.response }
        add_metadata(out)
        out
      end

      def add_metadata(resp)
        resp.instance_eval do
          def response
            @response
          end

          def raw
            @response.raw
          end

          def response_headers
            @response.headers
          end

          def response_status
            @response.status
          end
        end
        resp
      end

      def get(path, params = {}, options = {})
        params[:limit] ||= 100 if options[:paginate] == true

        http_verb('GET', "#{path}?#{URI.encode_www_form(params)}") do |resp|
          begin
            out = JSON.parse(resp.body)
          rescue JSON::ParserError
            out = resp.body
          end
          out.instance_eval { @response = resp }
          add_metadata(out)

          if options[:paginate] && out.count == params[:limit]
            params[:after] = resp.headers['CB-AFTER']
            get(path, params, options) do |pages|
              out += pages
              add_metadata(out)
              yield(out)
            end
          else
            yield(out)
          end
        end
      end

      def post(path, params = {})
        http_verb('POST', path, params.to_json) do |resp|
          begin
            out = JSON.parse(resp.body)
          rescue JSON::ParserError
            out = resp.body
          end
          out.instance_eval { @response = resp }
          add_metadata(out)
          yield(out)
        end
      end

      def delete(path)
        http_verb('DELETE', path) do |resp|
          begin
            out = JSON.parse(resp.body)
          rescue
            out = resp.body
          end
          out.instance_eval { @response = resp }
          add_metadata(out)
          yield(out)
        end
      end

      def http_verb(_method, _path, _body)
        fail NotImplementedError
      end

      def self.whitelisted_certificates
        path = File.expand_path(File.join(File.dirname(__FILE__), 'ca-coinbase.crt'))

        certs = [ [] ]
        File.readlines(path).each do |line|
          next if ["\n","#"].include?(line[0])
          certs.last << line
          certs << [] if line == "-----END CERTIFICATE-----\n"
        end

        result = OpenSSL::X509::Store.new

        certs.each do |lines|
          next if lines.empty?
          cert = OpenSSL::X509::Certificate.new(lines.join)
          result.add_cert(cert)
        end

        result
      end
    end
  end
end
