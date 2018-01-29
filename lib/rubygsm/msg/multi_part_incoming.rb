module Gsm
  # MultipartIncoming
  class MultiPartIncoming
    attr_reader :id, :from, :device, :parts, :last_updated

    COMPLETION_WAITING_TIME_LIMIT = 60

    def initialize(sms)
      raise 'Initial sms has part_number larger than number_of_parts' if sms.part_number > sms.number_of_parts
      @id = sms.multipart_id
      @from = sms.from
      @device = sms.device
      @parts = Array.new(sms.number_of_parts)
      do_add(sms)
    end

    def add(sms)
      assert_can_be_added(sms)
      do_add(sms)
    end

    def assert_can_be_added(sms)
      raise 'New sms has too large part_number.' if sms.part_number > parts.size
      raise 'Place for a new sms is already occupied.' unless parts[sms.part_number - 1].nil?
    end

    def do_add(sms)
      parts[sms.part_number - 1] = sms
      @last_updated = Time.now
    end

    def should_include(sms)
      sms.multipart_id == id && sms.from == from
    end

    def complete?
      !parts.include?(nil)
    end

    def no_hope_for_completion?
      last_updated < Time.now - COMPLETION_WAITING_TIME_LIMIT
    end

    def squash
      joined_pdu = joined_property(&:pdu)
      joined_text = joined_property(&:text)
      earliest_sent = parts.reject(&:nil?).map(&:sent).min
      sms_info = PDUTools::MessagePart.new(from, joined_text, earliest_sent, nil, nil)
      Gsm::Incoming.new(device, sms_info, joined_pdu)
    end

    def joined_property
      parts.map { |sms| sms.nil? ? '[missing part]' : (yield sms if block_given?) }.join("\n")
    end
  end
end
