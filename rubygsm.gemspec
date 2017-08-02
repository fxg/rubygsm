Gem::Specification.new do |s|
	s.name     = "rubygsm"
	s.version  = "0.51.1"
	s.date     = "2017-11-16"
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
end
