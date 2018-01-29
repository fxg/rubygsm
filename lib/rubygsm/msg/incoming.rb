module Gsm
  # Incoming
  class Incoming
    attr_reader :device, :from, :sent, :date, :to, :text, :pdu, :complete, :multipart_id, :number_of_parts, :part_number

    def initialize(device, decoded_pdu, pdu = nil)
      @device = device
      @to = device.self_phone_number unless device.nil?
      @from = decoded_pdu.address.gsub("\u0000", '')
      @sent = decoded_pdu.timestamp
      @text = decoded_pdu.body
      @complete = decoded_pdu.complete?
      unless @complete
        multipart = decoded_pdu.user_data_header[:multipart]
        @multipart_id = multipart[:reference]
        @number_of_parts = multipart[:parts]
        @part_number = multipart[:part_number]
      end
      @pdu = pdu
      # assume that the message was received right now, since we don't have an incoming buffer
      @date = Time.now
    end
  end
end
