require 'spec_helper'

describe Coinbase::Exchange do
  before :all do
    @obj = Coinbase::Exchange::APIObject.new('text' => 'test 123',
                                             'decimal' => '123456.789',
                                             'btc' => '฿ 1.23456789',
                                             'usd' => '$ 1,234,567.89',
                                             'gbp' => '£ 1,234,567.89',
                                             'eur' => '€ 1,234,567.89')
  end

  it "doesn't do anything to generic text" do
    expect(@obj.text.class).to eq(String)
  end

  it "converts numeric string to bigdecimal" do
    expect(@obj.decimal.class).to eq(BigDecimal)
  end

  it "converts currency to bigdecimal" do
    expect(@obj.btc.class).to eq(BigDecimal)
    expect(@obj.usd.class).to eq(BigDecimal)
    expect(@obj.gbp.class).to eq(BigDecimal)
    expect(@obj.eur.class).to eq(BigDecimal)
  end
end
