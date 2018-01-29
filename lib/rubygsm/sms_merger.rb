# SmsMerger
class SmsMerger
  def self.add(incoming_multi_parts, incoming, msg)
    if msg.complete
      incoming.push(msg)
    else
      add_as_part(incoming_multi_parts, msg)
    end
  end

  def self.add_as_part(incoming_multi_parts, msg)
    compatible_multi_parts = incoming_multi_parts.select { |multi_sms| multi_sms.should_include(msg) }
    if compatible_multi_parts.empty?
      incoming_multi_parts.push(Gsm::MultiPartIncoming.new(msg))
    elsif compatible_multi_parts.size == 1
      compatible_multi_parts.first.add(msg)
    else
      raise 'More than one multipart sms with given id and "from" parameter has been found'
    end
  end

  def self.merge(incoming_multi_parts, incoming)
    incoming_multi_parts.delete_if { |multi_sms| merged?(multi_sms, incoming) }
  end

  def self.merged?(multi_sms, incoming)
    if multi_sms.complete? || multi_sms.no_hope_for_completion?
      squashed_sms = multi_sms.squash
      incoming.push(squashed_sms)
      true
    else
      false
    end
  end
end
