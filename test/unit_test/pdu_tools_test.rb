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
    end

    def test_decoding_numbers
      pdu = '07918497908906F0040B918406591552F30000711192415323400AB0986C46ABD96EB81C'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal '0123456789', decoded_pdu.body
      assert_equal '2017-11-29 14:35:32 +0100', decoded_pdu.timestamp.to_s
      assert_equal '+48609551253', decoded_pdu.address
    end

    def test_decoding_russian_letters
      pdu = '07918497908906F0040B918406591552F300087111423192824012044F0441044504340447043B044E04490436'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'ясхдчлющж', decoded_pdu.body
      assert_equal '2017-11-24 13:29:28 +0100', decoded_pdu.timestamp.to_s
      assert_equal '+48609551253', decoded_pdu.address
    end

    def test_decoding_polish_letters
      pdu = '07918497908906F0040B918406591552F30008711142312291401C015A00760107011900F30144017C002D017A007200F3006401420061'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'Śvćęóńż-źródła', decoded_pdu.body
      assert_equal '2017-11-24 13:22:19 +0100', decoded_pdu.timestamp.to_s
      assert_equal '+48609551253', decoded_pdu.address
    end

    def test_decoding_czech_letters
      pdu = '07918497908906F0040B918406591552F30008711192418254401E00FA016F00FD017E00E1010D010F00E9011B00ED014800F3015901610165'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'úůýžáčďéěíňóřšť', decoded_pdu.body
      assert_equal '2017-11-29 14:28:45 +0100', decoded_pdu.timestamp.to_s
      assert_equal '+48609551253', decoded_pdu.address
    end

    def test_decoding_special_chars
      pdu = '07918497908906F0040B918406591552F30008711192411252405000400026005F00280029003A003B002200210023003D002F002B003F00B7212200AE0060005E00A500AB00BB007B007D00A90024007C00B0005B005D003C003E00A300A200A10025002A005C007E00BF'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal '@&_():;"!#=/+?·™®`^¥«»{}©$|°[]<>£¢¡%*\~¿', decoded_pdu.body
      assert_equal '2017-11-29 14:21:25 +0100', decoded_pdu.timestamp.to_s
      assert_equal '+48609551253', decoded_pdu.address
    end

    def test_decoding_multiline_text
      pdu = '07918497908906F0040B918406591552F300007111924183404014CCB4BB0C8A2998697719245330D3EE326806'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal "Line 1\nLine 2\nLine 3", decoded_pdu.body
      assert_equal '2017-11-29 14:38:04 +0100', decoded_pdu.timestamp.to_s
      assert_equal '+48609551253', decoded_pdu.address
    end
  end
end