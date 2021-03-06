# Copyright 2014 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'spec_helper'

describe Service::PagerDuty do
  before :each do
    @pagerduty = Service::PagerDuty.new('abc123')
    FakeWeb.register_uri :post,
                         Squash::Configuration.pagerduty.api_url,
                         response: File.read(Rails.root.join('spec', 'fixtures', 'pagerduty_response.json'))

  end

  [:trigger, :acknowledge, :resolve].each do |method|
    describe "##{method}" do
      it "should apply headers to the request" do
        @pagerduty.send method, 'foobar'

        auth = case Squash::Configuration.pagerduty.authentication.strategy
                 when 'token' then /^Token token=/
                 when 'basic' then /^Basic /
               end
        expect(FakeWeb.last_request['Authorization']).to match(auth)
        expect(FakeWeb.last_request['Content-Type']).to eql('application/json')
      end

      it "should parse the response" do
        resp = @pagerduty.send(method, 'abc123')
        expect(resp.http_status).to eql(200)
        expect(resp).to be_success
        expect(resp.attributes).to eql('status' => 'success', 'message' => 'You did it!')
        expect(resp.status).to eql('success')
      end

      it "should use an HTTP proxy if configured" do
        Squash::Configuration.pagerduty[:http_proxy] = Configoro::Hash.new('host' => 'myhost', 'port' => 123)
        http = Net::HTTP
        proxy = Net::HTTP::Proxy(nil, nil, nil, nil)
        expect(Net::HTTP).to receive(:Proxy).once.with('myhost', 123).and_return(http)
        allow(Net::HTTP).to receive(:Proxy).and_return(proxy)

        resp = @pagerduty.send(method, 'abc123')
        expect(resp.http_status).to eql(200)
        expect(resp).to be_success
        expect(resp.attributes).to eql('status' => 'success', 'message' => 'You did it!')
        expect(resp.status).to eql('success')

        Squash::Configuration.pagerduty.delete :http_proxy
      end
    end
  end

  describe "#trigger" do
    it "should send a trigger event" do
      @pagerduty.trigger 'foobar'
      body = JSON.parse(FakeWeb.last_request.body)
      expect(body['service_key']).to eql('abc123')
      expect(body['event_type']).to eql('trigger')
      expect(body['description']).to eql('foobar')
    end
  end

  describe "#acknowledge" do
    it "should send an acknowledge event" do
      @pagerduty.acknowledge 'foobar'
      body = JSON.parse(FakeWeb.last_request.body)
      expect(body['service_key']).to eql('abc123')
      expect(body['event_type']).to eql('acknowledge')
      expect(body['incident_key']).to eql('foobar')
    end
  end

  describe "#resolve" do
    it "should send a resolve event" do
      @pagerduty.resolve 'foobar'
      body = JSON.parse(FakeWeb.last_request.body)
      expect(body['service_key']).to eql('abc123')
      expect(body['event_type']).to eql('resolve')
      expect(body['incident_key']).to eql('foobar')
    end
  end
end unless Squash::Configuration.pagerduty.disabled?
