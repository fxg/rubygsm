#!/usr/bin/env ruby
# vim: noet

module Gsm
	class Incoming
		attr_reader :device, :from, :sent, :date, :to, :text, :pdu
		
		def initialize(device, from, sent, text, pdu = nil)
			
			# move all arguments into read-only
			# attributes. ugly, but Struct only
			# supports read/write attrs
			@device = device
			@from = from
			@sent = sent
			@to = device.self_phone_number
			@text = text
			@pdu = pdu
			
			# assume that the message was
			# received right now, since we
			# don't have an incoming buffer
			@date = Time.now
		end
		
		# Returns the sender of this message,
		# so incoming and outgoing messages
		# can be logged in the same way.
		def number
			sender
		end
	end
end
