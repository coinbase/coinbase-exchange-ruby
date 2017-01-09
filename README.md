# Coinbase Exchange Gem

## REST Client

We provide an exchange client that is a thin wrapper over the exchange API.  The purpose of this Readme is to provide context for using the gem effectively.  For a detailed overview of the information that's available through the API, we recommend consulting the official documentation.
* https://docs.gdax.com/#api

We provide a synchronous and asynchronous client.  The only functional difference between the two clients is that the asynchronous client must be started inside the Eventmachine reactor loop.

**Synchronous Client**

```ruby
require 'coinbase/exchange'

rest_api = Coinbase::Exchange::Client.new(api_key, api_secret, api_pass)
while true
  sleep 10
  rest_api.last_trade(product_id: "BTC-GBP") do |resp|
    p "Spot Rate: £ %.2f" % resp.price
  end
end
```

**Asynchronous Client**

```ruby
require 'coinbase/exchange'
require 'eventmachine'

rest_api = Coinbase::Exchange::AsyncClient.new(api_key, api_secret, api_pass)
EM.run {
  EM.add_periodic_timer(10) {
    rest_api.last_trade(product_id: "BTC-GBP") do |resp|
      p "Spot Rate: £ %.2f" % resp.price
    end
  }
}
```

## Usage

### Initialization

To initialize the client, simply pass in an API Key, API Secret, and API Passphrase which you generate on the web interface:
* https://gdax.com/settings

```ruby
rest_api = Coinbase::Exchange::Client.new(api_key, api_secret, api_pass)
```

```ruby
rest_api = Coinbase::Exchange::AsyncClient.new(api_key, api_secret, api_pass)
```

**Default Product**

Coinbase supports trading bitcoin in several currencies.  If you wish to trade a different currency, you can specify an alternative default currency.

```ruby
gbp_client = Coinbase::Exchange::Client.new(api_key, api_secret, api_pass,
                                            product_id: "BTC-GBP")
```

**Sandbox**

You can initialize a connection to the sandbox by specifying an alternative api endpoint.

```ruby
sandbox = Coinbase::Exchange::Client.new(api_key, api_secret, api_pass,
                                          api_url: "https://api-public.sandbox.gdax.com")
```

### Methods

The default representation of return data is an unmodified hash from the JSON blob returned in the body of the API response.  The response should be accessed in a block like this.

```ruby
rest_api.last_trade do |resp|
  p "Spot Rate: $ %.2f" % BigDecimal(resp['price'])
end
```

Note, the synchronous client will also return the same data.  However, this is discouraged since it will make porting code to an asynchronous client more difficult.  Here is an example of what that might look like.

```ruby
resp = rest_api.last_trade
p "Spot Rate: $ %.2f" % BigDecimal(resp['price'])
```

### Parameters

The gem will automatically encode any additional parameters you pass to method calls.  For instance to get the full orderbook, you must explicitly set the level parameter to 3.

```ruby
rest_api.orderbook(level: 3) do |resp|
  p "There are #{resp['bids'].count} open bids on the orderbook"
  p "There are #{resp['asks'].count} open asks on the orderbook"
end
```

### Return Values

Data format is a sensitive issue when writing financial software.  The exchange API represents monetary data in string format.  This is a good intermediary data format for the user to apply their own data format, but is not especially useful on its own.

For representing monetary data in ruby, we recommend using the [BigDecimal] (http://ruby-doc.org/stdlib-2.1.1/libdoc/bigdecimal/rdoc/BigDecimal.html) library.  If you access data by calling response items as though they were methods on the response itself.  If you access data this way, any numerical data will be converted to BigDecimal format.

```ruby
rest_api.orders(before: Time.now - 60*60) do |resp|
  resp.each do |order|
    p sprintf "#{order.side} ฿ %.8f for $ %.2f", order.size, order.price
  end
end
```

### Errors

The gem will throw an error if it detects an exception.  The possible errors are:

|Error|Description
|---|---
|APIError|Parent class for all errors.
|BadRequestError|Server returned status 400.
|NotAuthorizedError|Server returned status 401.
|ForbiddenError|Server returned status 403.
|NotFoundError|Server returned status 404.
|RateLimitError|Server returned status 429.
|InternalServerError|Server returned status 500.

### Metadata

You may need more fine-grained access to API response than just the body.  We additionally provide access to the response headers, status, and the raw response as represented by the underlying library.

```ruby
rest_api.last_trade do |resp|
  p "Status: #{resp.response_status}"
  p "Headers: #{resp.response_headers}"
  p "Response: #{resp.raw}"
end
```

## Endpoints

### [Market Data] (https://docs.gdax.com/#market-data)

Coinbase supports trading in multiple currencies.  When interacting with market data, you can get information about a product other than your default by setting the product_id parameter.

```ruby
rest_api.last_trade(product_id: 'BTC-GBP') do |resp|
  p "The spot rate is £ %.2f" % resp.price
end
```

**currencies**

Fetches a list of currencies we support.

```ruby
rest_api.currencies do |resp|
  resp.each do |currency|
    p "The symbol for #{currency.name} is #{currency.id}"
  end
end
```

**products**

Fetches a list of products we offer.

```ruby
rest_api.products do |resp|
  resp.each do |product|
    p "The most #{product.base_currency} you can buy with #{product.quote_currency} is %f" % product.base_max_size
  end
end
```

**orderbook**

Downloads a list of all open orders on our exchange.

```ruby
rest_api.orderbook do |resp|
  p resp
end
```

If you wish to download a level 2 or level 3 orderbook, pass a level parameter to the method.

```ruby
rest_api.orderbook(level: 3) do |resp|
  p "There are #{resp.bids.count} open bids on the orderbook"
  p "There are #{resp.asks.count} open asks on the orderbook"
end
```

**last_trade**

Downloads information about the last trade, which is exposed through the /ticker endpoint.

```ruby
rest_api.last_trade do |resp|
  p "The spot rate is $ %.2f" %  resp.price
end
```

**trade_history**

Downloads recent trades.  Please be aware that if you don't explicitly pass a before parameter this will recursively download every trade that's ever been placed.

```ruby
rest_api.trade_history(before: Time.now - 10*60) do |resp|
  p "#{resp.count} trades have occurred in the past 10 minutes."
end
```

**price_history**

Downloads price history.  We recommend setting a start parameter.  You may also find the granularity parameter useful.

```ruby
rest_api.price_history(start: Time.now - 60*60, granularity: 60) do |resp|
  p "In the past hour, the maximum price movement was $ %.2f" % resp.map { |candle| candle.high - candle.low }.max
end
```

**daily_stats**

Downloads price information over the past 24 hours.

```ruby
rest_api.daily_stats do |resp|
  p "The highest price in in the past 24 hours was %.2f" % resp.high
  p "The lowest price in in the past 24 hours was %.2f" % resp.low
end
```

### [Accounts] (https://docs.gdax.com/#accounts)

**accounts**

Downloads information about your accounts.

```ruby
rest_api.accounts do |resp|
  resp.each do |account|
    p "#{account.id}: %.2f #{account.currency} available for trading" % account.available
  end
end
```

**account**

Downloads information about a single account.  You must pass the account id as the first parameter.

```ruby
rest_api.account(account_id) do |account|
  p "Account balance is %.2f #{account.currency}" % account.balance
end
```

**account_history**

Downloads a ledger of transfers, matches, and fees associated with an account.  You must pass the account id as the first parameter.

```ruby
rest_api.account_history(account_id) do |resp|
  p resp
end
```

**account_holds**

Holds are placed on an account for open orders.  This will download a list of all account holds.

```ruby
rest_api.account_holds(account_id) do |resp|
  p resp
end
```

### [Orders] (https://docs.gdax.com/#orders)

**bid**

Places a buy order.  Required parameters are amount and price.

```ruby
rest_api.bid(0.25, 250) do |resp|
  p "Order ID is #{resp.id}"
end
```

**buy**

This is an alias for bid.

```ruby
rest_api.buy(0.25, 250) do |resp|
  p "Order ID is #{resp.id}"
end
```

**ask**

Places a sell order.  Required parameters are amount and price.

```ruby
rest_api.ask(0.25, 250) do |resp|
  p "Order ID is #{resp.id}"
end
```

**sell**

This is an alias for ask.

```ruby
rest_api.sell(0.25, 250) do |resp|
  p "Order ID is #{resp.id}"
end
```

**cancel**

Cancels an order.  This returns no body, but you can still pass a block to execute on a successful return.

```ruby
rest_api.cancel(order_id) do
  p "Order canceled successfully"
end
```

**orders**

Downloads a list of all your orders.  Most likely, you'll only care about your open orders when using this.

```ruby
rest_api.orders(status: open) do |resp|
  p "You have #{resp.count} open orders."
end
```

**order**

Downloads information about a single order.

```ruby
rest_api.order(order_id) do |resp|
  p "Order status is #{resp.status}"
end
```

**fills**

Downloads a list of fills.

```ruby
rest_api.fills do |resp|
  p resp
end
```

### [Transfers] (https://docs.gdax.com/#transfer-funds)

**deposit**

Deposit money from a Coinbase wallet.

```ruby
rest_api.deposit(wallet_id, 10) do |resp|
  p "Deposited 10 BTC"
end
```

**withdraw**

Withdraw money for your Coinbase wallet.

```ruby
rest_api.withdraw(wallet_id, 10) do |resp|
  p "Withdrew 10 BTC"
end
```

### Other

**server_time**

Download the server time.

```ruby
rest_api.server_time do |resp|
  p "The time on the server is #{resp}"
end
```

## Websocket Client

We recommend reading the official websocket documentation before proceeding.

* https://docs.gdax.com/#websocket-feed

We provide a websocket interface in the gem for convenience.  This is typically used to build a real-time orderbook, although it can also be used for simpler purposes such as tracking the market rate, or tracking when your orders fill.  Like the asynchronous client, this depends Eventmachine for asynchronous processing.

Please consider setting the keepalive flag to true when initializing the websocket.  This will cause the websocket to proactively refresh the connection whenever it closes.

```ruby
websocket = Coinbase::Exchange::Websocket.new(keepalive: true)
```

Before starting the websocket, you should hook into whatever messages you're interested in by passing a block to the corresponding method.  The methods you can use for access are open, match, change, done, and error.  Additionally, you can use message to run a block on every websocket event.

```ruby
require 'coinbase/exchange'
require 'eventmachine'

websocket = Coinbase::Exchange::Websocket.new(product_id: 'BTC-GBP',
                                              keepalive: true)
websocket.match do |resp|
  p "Spot Rate: £ %.2f" % resp.price
end

EM.run do
  websocket.start!
  EM.add_periodic_timer(1) {
    websocket.ping do
      p "Websocket is alive"
    end
  }
  EM.error_handler { |e|
    p "Websocket Error: #{e.message}"
  }
end
```

If started outside the reactor loop, the websocket client will use a very basic Eventmachine handler.

```ruby
require 'coinbase/exchange'

websocket = Coinbase::Exchange::Websocket.new(product_id: 'BTC-GBP')
websocket.match do |resp|
  p "Spot Rate: £ %.2f" % resp.price
end
websocket.start!
```
