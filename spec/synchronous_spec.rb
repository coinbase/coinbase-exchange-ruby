require 'spec_helper'

describe Coinbase::Exchange::Client do
  before :all do
    @client = Coinbase::Exchange::Client.new 'api_pass', 'api_key', 'api_secret'
  end

  it "responds to all endpoints" do
    endpoints.each do |ref|
      expect(@client).to respond_to(ref)
    end
  end

  it "makes requests synchronously" do
    stub_request(:get, /.*/).to_return(body: mock_collection.to_json)
    success = true
    EM.run do
      @client.orders { EM.stop }
      success = false
    end
    expect(success)
  end

  it "gets currencies" do
    stub_request(:get, /currencies/).to_return(body: mock_collection.to_json)
    @client.currencies do |out|
      out.each do |item|
        expect(item.class).to eq(Coinbase::Exchange::APIObject)
        expect(item).to eq(mock_item)
      end
    end
  end

  it "gets products" do
    stub_request(:get, /products/).to_return(body: mock_collection.to_json)
    @client.products do |out|
      out.each do |item|
        expect(item.class).to eq(Coinbase::Exchange::APIObject)
        expect(item).to eq(mock_item)
      end
    end
  end

  it "gets BTC-USD ticker by default" do
    stub_request(:get, /products.BTC-USD.ticker/)
      .to_return(body: mock_item.to_json)
    @client.last_trade do |out|
      expect(out.class).to eq(Coinbase::Exchange::APIObject)
      expect(out).to eq(mock_item)
    end
  end

  it "gets arbitrary ticker" do
    stub_request(:get, /products.BTC-LTC.ticker/)
      .to_return(body: mock_item.to_json)
    @client.last_trade(product_id: "BTC-LTC") do |out|
      expect(out.class).to eq(Coinbase::Exchange::APIObject)
      expect(out).to eq(mock_item)
    end
  end

  it "gets trade history" do
    # FIXME
  end

  it "gets order history" do
    # FIXME
  end

  it "gets accounts" do
    stub_request(:get, /accounts/).to_return(body: mock_collection.to_json)
    @client.accounts do |out|
      out.each do |item|
        expect(item.class).to eq(Coinbase::Exchange::APIObject)
        expect(item).to eq(mock_item)
      end
    end
  end

  it "gets account" do
    stub_request(:get, /accounts.test/).to_return(body: mock_item.to_json)
    @client.account("test") do |out|
      expect(out.class).to eq(Coinbase::Exchange::APIObject)
      expect(out).to eq(mock_item)
    end
  end

  it "gets account history" do
    stub_request(:get, /accounts.test.ledger/)
      .to_return(body: mock_collection.to_json)
    @client.account_history("test") do |out|
      out.each do |item|
        # FIXME: Add a check for correct model
        expect(item).to eq(mock_item)
      end
    end
  end

  it "gets account holds" do
    stub_request(:get, /accounts.test.holds/)
      .to_return(body: mock_collection.to_json)
    @client.account_holds("test") do |out|
      out.each do |item|
        expect(item.class).to eq(Coinbase::Exchange::APIObject)
        expect(item).to eq(mock_item)
      end
    end
  end

  it "places a bid" do
    stub_request(:post, /orders/)
      .with(body: hash_including('side' => 'buy'))
      .to_return(body: mock_item.to_json)
    @client.bid(10, 250) do |out|
      expect(out.class).to eq(Coinbase::Exchange::APIObject)
      expect(out['status']).to eq('OK')
    end
  end

  it "places an ask" do
    stub_request(:post, /orders/)
      .with(body: hash_including('side' => 'sell'))
      .to_return(body: mock_item.to_json)
    @client.ask(10, 250) do |out|
      expect(out.class).to eq(Coinbase::Exchange::APIObject)
      expect(out['status']).to eq('OK')
    end
  end

  it "cancels an order" do
    stub_request(:delete, /orders.test/).to_return(body: nil)
    @client.cancel('test') do |out|
      expect(out).to eq({})
    end
  end

  it "gets orders" do
    stub_request(:get, /orders/).to_return(body: mock_collection.to_json)
    @client.orders do |out|
      out.each do |item|
        expect(item.class).to eq(Coinbase::Exchange::APIObject)
        expect(item['status']).to eq('OK')
      end
    end
  end

  it "gets an order" do
    stub_request(:get, /orders.test/).to_return(body: mock_item.to_json)
    @client.order('test') do |out|
      expect(out.class).to eq(Coinbase::Exchange::APIObject)
      expect(out['status']).to eq('OK')
    end
  end

  it "gets fills" do
    stub_request(:get, /fills/).to_return(body: mock_collection.to_json)
    @client.fills do |out|
      out.each do |item|
        expect(item.class).to eq(Coinbase::Exchange::APIObject)
        expect(item['status']).to eq('OK')
      end
    end
  end

  it "makes a deposit" do
    stub_request(:post, /transfers/)
      .with(body: hash_including('type' => 'deposit'))
      .to_return(body: mock_item.to_json)
    @client.deposit(SecureRandom.uuid, 10) do |out|
      expect(out.class).to eq(Coinbase::Exchange::APIObject)
      expect(out['status']).to eq('OK')
    end
  end

  it "makes a withdrawal" do
    stub_request(:post, /transfers/)
      .with(body: hash_including('type' => 'withdraw'))
      .to_return(body: mock_item.to_json)
    @client.withdraw(SecureRandom.uuid, 10) do |out|
      expect(out.class).to eq(Coinbase::Exchange::APIObject)
      expect(out['status']).to eq('OK')
    end
  end

  it "makes a withdrawal to a payment method" do
    payment_method_id = SecureRandom.uuid
    stub_request(:post, /withdrawals.payment-method/)
      .with(body: {amount: 1.5, currency: 'BTC', payment_method_id: payment_method_id})
      .to_return(body: mock_item.to_json)
    @client.payment_method_withdrawal(1.5, 'BTC', payment_method_id) do |out|
      expect(out.class).to eq(Coinbase::Exchange::APIObject)
      expect(out['status']).to eq('OK')
    end
  end

  it "makes a withdrawal to a Coinbase account" do
    coinbase_account_id = SecureRandom.uuid
    stub_request(:post, /withdrawals.coinbase-account/)
      .with(body: {amount: 1.5, currency: 'BTC', coinbase_account_id: coinbase_account_id})
      .to_return(body: mock_item.to_json)
    @client.coinbase_withdrawal(1.5, 'BTC', coinbase_account_id) do |out|
      expect(out.class).to eq(Coinbase::Exchange::APIObject)
      expect(out['status']).to eq('OK')
    end
  end

  it "makes a withdrawal to a crypto address" do
    crypto_address = SecureRandom.uuid
    stub_request(:post, /withdrawals.crypto/)
      .with(body: {amount: 1.5, currency: 'BTC', crypto_address: crypto_address})
      .to_return(body: mock_item.to_json)
    @client.crypto_withdrawal(1.5, 'BTC', crypto_address) do |out|
      expect(out.class).to eq(Coinbase::Exchange::APIObject)
      expect(out['status']).to eq('OK')
    end
  end


end
