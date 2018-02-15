# PduDecoder
class PduDecoder
  def self.decode(pdu)
    decode_with_pdu_sms(pdu)
  rescue StandardError
    raise "Problem with decoding PDU: #{pdu}"
  end

  def self.decode_with_pdu_sms(pdu)
    decoded_pdu = PduSms::PacketDataUnit.decode(pdu)
    DecodedPdu.new(
      decoded_pdu.get_phone_number,
      Time.at(decoded_pdu.service_center_time_stamp.get_time),
      decoded_pdu.get_message,
      decoded_pdu.id_message,
      decoded_pdu.all_parts,
      decoded_pdu.part_number
    )
  end

  # "pdu-tools" is an old pdu decoder used previously.
  # Its version 0.0.12 seems to be worse than the latest version of "pdu-sms".
  # However, it may change in the future, so the code below may be useful."

  # def self.decode_with_pdu_tools(pdu)
  #   decoded_pdu = PDUTools::Decoder.new(pdu).decode
  #   if decoded_pdu.complete?
  #     DecodedPdu.new(decoded_pdu.address, decoded_pdu.timestamp, decoded_pdu.body)
  #   else
  #     multipart = decoded_pdu.user_data_header[:multipart]
  #     DecodedPdu.new(
  #       decoded_pdu.address,
  #       decoded_pdu.timestamp,
  #       decoded_pdu.body,
  #       multipart[:reference],
  #       multipart[:parts],
  #       multipart[:part_number]
  #     )
  #   end
  # end
end
