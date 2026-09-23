# frozen_string_literal: true

module WebSearchHttpStub
  Response = Struct.new(:code, :body, :headers) do
    def [](name)
      return if headers.nil?

      headers[name] || headers[name.to_s] || headers[name.to_s.downcase]
    end
  end

  def stub_net_http(response: nil, error: nil)
    captured = { calls: 0 }
    fake = Object.new
    fake.define_singleton_method(:use_ssl=) { |value| captured[:use_ssl] = value }
    fake.define_singleton_method(:verify_mode=) { |value| captured[:verify_mode] = value }
    fake.define_singleton_method(:open_timeout=) { |value| captured[:open_timeout] = value }
    fake.define_singleton_method(:read_timeout=) { |value| captured[:read_timeout] = value }
    fake.define_singleton_method(:write_timeout=) { |value| captured[:write_timeout] = value }
    fake.define_singleton_method(:request) do |request|
      captured[:calls] += 1
      captured[:request] = request
      raise error if error

      response
    end

    Net::HTTP.stub(:new, lambda { |host, port|
      captured[:host] = host
      captured[:port] = port
      fake
    }) do
      yield captured
    end
  end

  def json_response(body, status: 200, headers: {})
    Response.new(status.to_s, body.is_a?(String) ? body : JSON.generate(body), headers)
  end

  def request_params(request)
    query = URI.parse("https://example.com#{request.path}").query
    URI.decode_www_form(query.to_s).to_h
  end
end
