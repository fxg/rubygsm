class DecodedPdu
  attr_reader :from, :sent, :text, :multipart_id, :number_of_parts, :part_number

  def initialize(from, sent, text, multipart_id = nil, number_of_parts = nil, part_number = nil)
    @from = from
    @sent = sent
    @text = text
    @multipart_id = multipart_id
    @number_of_parts = number_of_parts
    @part_number = part_number
  end

  def complete?
    multipart_id.nil?
  end
end
