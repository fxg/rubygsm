require 'minitest/autorun'
require 'rubygsm'

module UnitTest
  class PduToolsTest < Minitest::Test
    def test_decoding_ordinary_text
      pdu = '07918497908906F0040B918406591552F30000711192413371400E4F3939ED0ECBF3207A194F7701'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'Ordinary text.', decoded_pdu.body
      assert_equal '2017-11-29 14:33:17 +0100', decoded_pdu.timestamp.to_s
      assert_equal '+48609551253', decoded_pdu.address
      assert_nil decoded_pdu.user_data_header
    end

    def test_decoding_numbers
      pdu = '07918497908906F0040B918406591552F30000711192415323400AB0986C46ABD96EB81C'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal '0123456789', decoded_pdu.body
      assert_equal '2017-11-29 14:35:32 +0100', decoded_pdu.timestamp.to_s
      assert_equal '+48609551253', decoded_pdu.address
      assert_nil decoded_pdu.user_data_header
    end

    def test_decoding_russian_letters
      pdu = '07918497908906F0040B918406591552F300087111423192824012044F0441044504340447043B044E04490436'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'ясхдчлющж', decoded_pdu.body
      assert_equal '2017-11-24 13:29:28 +0100', decoded_pdu.timestamp.to_s
      assert_equal '+48609551253', decoded_pdu.address
      assert_nil decoded_pdu.user_data_header
    end

    def test_decoding_polish_letters
      pdu = '07918497908906F0040B918406591552F30008711142312291401C015A00760107011900F30144017C002D017A007200F3006401420061'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'Śvćęóńż-źródła', decoded_pdu.body
      assert_equal '2017-11-24 13:22:19 +0100', decoded_pdu.timestamp.to_s
      assert_equal '+48609551253', decoded_pdu.address
      assert_nil decoded_pdu.user_data_header
    end

    def test_decoding_czech_letters
      pdu = '07918497908906F0040B918406591552F30008711192418254401E00FA016F00FD017E00E1010D010F00E9011B00ED014800F3015901610165'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'úůýžáčďéěíňóřšť', decoded_pdu.body
      assert_equal '2017-11-29 14:28:45 +0100', decoded_pdu.timestamp.to_s
      assert_equal '+48609551253', decoded_pdu.address
      assert_nil decoded_pdu.user_data_header
    end

    def test_decoding_special_chars
      pdu = '07918497908906F0040B918406591552F30008711192411252405000400026005F00280029003A003B002200210023003D002F002B003F00B7212200AE0060005E00A500AB00BB007B007D00A90024007C00B0005B005D003C003E00A300A200A10025002A005C007E00BF'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal '@&_():;"!#=/+?·™®`^¥«»{}©$|°[]<>£¢¡%*\~¿', decoded_pdu.body
      assert_equal '2017-11-29 14:21:25 +0100', decoded_pdu.timestamp.to_s
      assert_equal '+48609551253', decoded_pdu.address
      assert_nil decoded_pdu.user_data_header
    end

    def test_decoding_multiline_text
      pdu = '07918497908906F0040B918406591552F300007111924183404014CCB4BB0C8A2998697719245330D3EE326806'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal "Line 1\nLine 2\nLine 3", decoded_pdu.body
      assert_equal '2017-11-29 14:38:04 +0100', decoded_pdu.timestamp.to_s
      assert_equal '+48609551253', decoded_pdu.address
      assert_nil decoded_pdu.user_data_header
    end

    def test_decoding_first_multipart
      pdu = '07918497908906F0400B918406591552F30008812020415390408C050003160301015B00660064006400660067006700200064002000640064006300630063006700620068006700660064006400630063006300640066004000330034005F0023003D002F003D00280029003A003B00220077006400660066006700660066006400650065006500720074002000670064007900200079006A0020006800640020006400640063'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'śfddfgg d ddcccgbhgfddcccdf@34_#=/=():;"wdffgffdeeert gdy yj hd ddc', decoded_pdu.body
      assert_equal '2018-02-02 14:35:09 +0100', decoded_pdu.timestamp.to_s
      assert_equal '+48609551253', decoded_pdu.address
      multipart = decoded_pdu.user_data_header[:multipart]
      assert_equal 22, multipart[:reference]
      assert_equal 3, multipart[:parts]
      assert_equal 1, multipart[:part_number]
    end

    def test_decoding_middle_multipart
      pdu = '07918497908906F0400B918406591552F30008812020415390408C050003160302006800680068006600640064006300660066006600660066006700670068006800670066006400660066006700680068006A002000680064002000640063006600670068006800670066006300660066006700670067006700660066006500650065006500650065006500650065006500200073002D00660020006600660067006700620076'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'hhhfddcfffffgghhgfdffghhj hd dcfghhgfcffggggffeeeeeeeeee s-f ffggbv', decoded_pdu.body
      assert_equal '2018-02-02 14:35:09 +0100', decoded_pdu.timestamp.to_s
      assert_equal '+48609551253', decoded_pdu.address
      multipart = decoded_pdu.user_data_header[:multipart]
      assert_equal 22, multipart[:reference]
      assert_equal 3, multipart[:parts]
      assert_equal 2, multipart[:part_number]
    end

    def test_decoding_last_multipart
      pdu = '07918497908906F0440B918406591552F30008812020415301408405000316030300630064006400640064006600760068006700200063002E0064002E00200064006600660020006800200068006700660020006300640020007600680068006700660064006600660067006700660066007600670067006600640066006600680068006A006A002000680064002000660063006700680068002000630064'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'cddddfvhg c.d. dff h hgf cd vhhgfdffggffvggfdffhhjj hd fcghh cd', decoded_pdu.body
      assert_equal '2018-02-02 14:35:10 +0100', decoded_pdu.timestamp.to_s
      assert_equal '+48609551253', decoded_pdu.address
      multipart = decoded_pdu.user_data_header[:multipart]
      assert_equal 22, multipart[:reference]
      assert_equal 3, multipart[:parts]
      assert_equal 3, multipart[:part_number]
    end
  end
end