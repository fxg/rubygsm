lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
test = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(test) unless $LOAD_PATH.include?(test)

Gem::Specification.new do |s|
  s.name     = 'rubygsm'
  s.version  = '0.60'
  s.date     = '2018-04-16'
  s.summary  = 'Send and receive SMS with a GSM modem'
  s.email    = 'adam.mckaig@gmail.com'
  s.homepage = 'https://github.com/kontomatik/rubygsm'
  s.authors  = ['Adam Mckaig', 'Pawel Pacholek']
  s.has_rdoc = true

  s.files = %w[
    rubygsm.gemspec
    README.rdoc
    lib/rubygsm.rb
    lib/rubygsm/core.rb
    lib/rubygsm/errors.rb
    lib/rubygsm/log.rb
    lib/rubygsm/msg/incoming.rb
    lib/rubygsm/msg/outgoing.rb
    bin/gsm-modem-band
  ]

  s.executables = %w[gsm-modem-band sms]

  s.add_dependency('pdu_sms', ['>=1.1.7'])
  s.add_dependency('serialport', ['>= 1.1.0'])

  s.add_development_dependency 'bundler', '~> 1.11'
  s.add_development_dependency 'minitest', '~> 5.10'
  s.add_development_dependency 'rake', '~> 12.0'
  s.add_development_dependency 'rubocop', '~> 0.55.0'
end
