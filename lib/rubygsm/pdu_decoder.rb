require 'pdu_tools'

# PduDecoder
class PduDecoder
  def self.decode(pdu)
    PDUTools::Decoder.new(pdu, :ms_to_sc).decode
  end
end
