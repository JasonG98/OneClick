require "json"

class CaskProbe
  attr_reader :values

  def initialize(token)
    @values = {
      "token" => token,
      "depends_on" => {},
    }
  end

  %w[version sha256 url name desc homepage app].each do |stanza|
    define_method(stanza) do |value|
      @values[stanza] = value
    end
  end

  def depends_on(**requirements)
    requirements.each do |name, value|
      @values["depends_on"][name.to_s] = value.to_s
    end
  end
end

def cask(token, &block)
  probe = CaskProbe.new(token)
  probe.instance_eval(&block)
  puts JSON.generate(probe.values)
end

load ARGV.fetch(0)
