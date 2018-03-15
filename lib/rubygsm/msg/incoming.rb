module Gsm
  class Incoming
    attr_reader :from, :sent, :date, :to, :text, :pdu, :multipart_id, :number_of_parts, :part_number

    def initialize(device, decoded_pdu, pdu = nil)
      @to = device.self_phone_number
      @from = decoded_pdu.from.gsub(/[^A-Za-z0-9]/, '')
      @sent = decoded_pdu.sent
      @text = decoded_pdu.text
      multipart_info(decoded_pdu) unless decoded_pdu.complete?
      @pdu = pdu
      @date = Time.now
    end

    def multipart_info(decoded_pdu)
      @multipart_id = decoded_pdu.multipart_id
      @number_of_parts = decoded_pdu.number_of_parts
      @part_number = decoded_pdu.part_number
    end
  end
end
