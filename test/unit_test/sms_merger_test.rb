require 'minitest/autorun'
require 'rubygsm'

module UnitTest
  class SmsMergerTest < Minitest::Test
    def test_sms_merger
      list = []
      multi_list = []
      single_sms = sms('sender', '2018-01-28 09:50:10 +0100', 'single', nil)
      SmsMerger.add(multi_list, list, single_sms)
      assert_equal 1, list.size
      assert_empty multi_list
      user_data_header = { multipart: { reference: 10, parts: 2, part_number: 1} }
      first_part = sms('sender', '2018-01-28 09:50:11 +0100', 'part 1', user_data_header)
      SmsMerger.add(multi_list, list, first_part)
      assert_equal 1, list.size
      assert_equal 1, multi_list.size
      parts = multi_list.first.parts
      assert_equal 2, parts.size
      refute_nil parts.first
      assert_nil parts.last
      user_data_header = { multipart: { reference: 10, parts: 2, part_number: 2} }
      second_part = sms('sender', '2018-01-28 09:50:12 +0100', 'part 2', user_data_header)
      SmsMerger.add(multi_list, list, second_part)
      assert_equal 1, list.size
      assert_equal 1, multi_list.size
      parts = multi_list.first.parts
      assert_equal 2, parts.size
      refute_nil parts.first
      refute_nil parts.last
      SmsMerger.merge(multi_list, list)
      assert_equal 2, list.size
      merged = list.last
      assert_equal "part 1\npart 2", merged.text
      assert_equal 'sender', merged.from
      assert_equal Time.parse('2018-01-28 09:50:11 +0100'), merged.sent
    end

    private

    def sms(from, sent, text, user_data_header)
      sms_info = PDUTools::MessagePart.new(from, text, Time.parse(sent), nil, user_data_header)
      Gsm::Incoming.new(nil, sms_info, nil)
    end
  end
end