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
        get("/currencies", params) do |resp|
          out = response_collection(resp)
          yield(out) if block_given?
        end
      end

      def products(params = {})
        get("/products", params) do |resp|
          out = response_collection(resp)
          yield(out) if block_given?
        end
      end

      def orderbook(params = {})
        product = params[:product_id] || @default_product
        get("/products/#{product}/book", params) do |resp|
          out = response_object(resp)
          yield(out) if block_given?
        end
      end

      def last_trade(params = {})
        product = params[:product_id] || @default_product
        get("/products/#{product}/ticker", params) do |resp|
          out = response_object(resp)
          yield(out) if block_given?
        end
      end

      def trade_history(params = {})
        product = params[:product_id] || @default_product
        get("/products/#{product}/trades", params, paginate: true) do |resp|
          out = response_collection(resp)
          yield(out) if block_given?
        end
      end

      def price_history(params = {})
        product = params[:product_id] || @default_product
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
          yield(out) if block_given?
        end
      end

      def daily_stats(params = {})
        product = params[:product_id] || @default_product
        get("/products/#{product}/stats", params) do |resp|
          resp["start"] = (Time.now - 24 * 60 * 60).to_s
          out = response_object(resp)
          yield(out) if block_given?
        end
      end

      #
      # Accounts
      #
      def accounts(params = {})
        get("/accounts", params) do |resp|
          out = response_collection(resp)
          yield(out) if block_given?
        end
      end

      def account(id, params = {})
        get("/accounts/#{id}", params) do |resp|
          out = response_object(resp)
          yield(out) if block_given?
        end
      end

      def account_history(id, params = {})
        get("/accounts/#{id}/ledger", params, paginate: true) do |resp|
          out = response_collection(resp)
          yield(out) if block_given?
        end
      end

      def account_holds(id, params = {})
        get("/accounts/#{id}/holds", params, paginate: true) do |resp|
          out = response_collection(resp)
          yield(out) if block_given?
        end
      end

      #
      # Orders
      #
      def bid(amt, price, params = {})
        params[:product_id] ||= @default_product
        params[:size] = amt
        params[:price] = price
        params[:side] = "buy"
        post("/orders", params) do |resp|
          out = response_object(resp)
          yield(out) if block_given?
        end
      end
      alias_method :buy, :bid

      def ask(amt, price, params = {})
        params[:product_id] ||= @default_product
        params[:size] = amt
        params[:price] = price
        params[:side] = "sell"
        post("/orders", params) do |resp|
          out = response_object(resp)
          yield(out) if block_given?
        end
      end
      alias_method :sell, :ask

      def cancel(id)
        delete("/orders/#{id}") do |resp|
          out = response_object(resp)
          yield(out) if block_given?
        end
      end

      def orders(params = {})
        params[:status] ||= "all"
        get("/orders", params, paginate: true) do |resp|
          out = response_collection(resp)
          yield(out) if block_given?
        end
      end

      def order(id, params = {})
        get("/orders/#{id}", params) do |resp|
          out = response_object(resp)
          yield(out) if block_given?
        end
      end

      def fills(params = {})
        get("/fills", params, paginate: true) do |resp|
          out = response_collection(resp)
          yield(out) if block_given?
        end
      end

      #
      # Transfers
      #
      def deposit(account_id, amt, params = {})
        params[:type] = "deposit"
        params[:coinbase_account_id] = account_id
        params[:amount] = amt
        post("/transfers", params) do |resp|
          out = response_object(resp)
          yield(out) if block_given?
        end
      end

      def withdraw(account_id, amt, params = {})
        params[:type] = "withdraw"
        params[:coinbase_account_id] = account_id
        params[:amount] = amt
        post("/transfers", params) do |resp|
          out = response_object(resp)
          yield(out) if block_given?
        end
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
    end
  end
end
