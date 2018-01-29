module Gsm
  # Incoming
  class Incoming
    attr_reader :from, :sent, :date, :to, :text, :pdu, :multipart_id, :number_of_parts, :part_number

    def initialize(device, decoded_pdu, pdu = nil)
      @to = device.self_phone_number
      @from = decoded_pdu.address.gsub("\u0000", '')
      @sent = decoded_pdu.timestamp
      @text = decoded_pdu.body
      multipart_info(decoded_pdu) unless decoded_pdu.complete?
      @pdu = pdu
      @date = Time.now
    end

    def multipart_info(decoded_pdu)
      multipart = decoded_pdu.user_data_header[:multipart]
      @multipart_id = multipart[:reference]
      @number_of_parts = multipart[:parts]
      @part_number = multipart[:part_number]
    end
  end
end
