lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
test = File.expand_path('../test', __FILE__)
$LOAD_PATH.unshift(test) unless $LOAD_PATH.include?(test)

Gem::Specification.new do |s|
	s.name     = "rubygsm"
	s.version  = "0.56"
	s.date     = "2018-03-13"
	s.summary  = "Send and receive SMS with a GSM modem"
	s.email    = "adam.mckaig@gmail.com"
	s.homepage = "https://github.com/kontomatik/rubygsm"
	s.authors  = ["Adam Mckaig", "Pawel Pacholek"]
	s.has_rdoc = true

	s.files = [
		"rubygsm.gemspec",
		"README.rdoc",
		"lib/rubygsm.rb",
		"lib/rubygsm/core.rb",
		"lib/rubygsm/errors.rb",
		"lib/rubygsm/log.rb",
		"lib/rubygsm/msg/incoming.rb",
		"lib/rubygsm/msg/outgoing.rb",
		"bin/gsm-modem-band"
	]

	s.executables = [
		"gsm-modem-band",
		"sms"
	]

	s.add_dependency("serialport", [">= 1.1.0"])
	s.add_dependency("pdu_sms", [">=1.1.5"])

  s.add_development_dependency 'minitest', '~> 5.10'
	s.add_development_dependency 'bundler', '~> 1.11'
	s.add_development_dependency 'rake', '~> 12.0'
end
