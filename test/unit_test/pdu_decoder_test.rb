require 'minitest/autorun'
require 'rubygsm'

module UnitTest
  class PduDecoderTest < Minitest::Test
    def test_decoding_ordinary_text
      pdu = '07918497908906F0040B918406591552F30000711192413371400E4F3939ED0ECBF3207A194F7701'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'Ordinary text.', decoded_pdu.text
      assert_equal Time.parse('2017-11-29 14:33:17 +0100'), decoded_pdu.sent
      assert_equal '+48609551253', decoded_pdu.from
      assert decoded_pdu.complete?
    end

    def test_decoding_numbers
      pdu = '07918497908906F0040B918406591552F30000711192415323400AB0986C46ABD96EB81C'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal '0123456789', decoded_pdu.text
      assert_equal Time.parse('2017-11-29 14:35:32 +0100'), decoded_pdu.sent
      assert_equal '+48609551253', decoded_pdu.from
      assert decoded_pdu.complete?
    end

    def test_decoding_russian_letters
      pdu = '07918497908906F0040B918406591552F300087111423192824012044F0441044504340447043B044E04490436'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'ясхдчлющж', decoded_pdu.text
      assert_equal Time.parse('2017-11-24 13:29:28 +0100'), decoded_pdu.sent
      assert_equal '+48609551253', decoded_pdu.from
      assert decoded_pdu.complete?
    end

    def test_decoding_polish_letters
      pdu = '07918497908906F0040B918406591552F30008711142312291401C015A00760107011900F30144017C002D017A007200F3006401420061'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'Śvćęóńż-źródła', decoded_pdu.text
      assert_equal Time.parse('2017-11-24 13:22:19 +0100'), decoded_pdu.sent
      assert_equal '+48609551253', decoded_pdu.from
      assert decoded_pdu.complete?
    end

    def test_decoding_czech_letters
      pdu = '07918497908906F0040B918406591552F30008711192418254401E00FA016F00FD017E00E1010D010F00E9011B00ED014800F3015901610165'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'úůýžáčďéěíňóřšť', decoded_pdu.text
      assert_equal Time.parse('2017-11-29 14:28:45 +0100'), decoded_pdu.sent
      assert_equal '+48609551253', decoded_pdu.from
      assert decoded_pdu.complete?
    end

    def test_decoding_special_chars
      pdu = '07918497908906F0040B918406591552F30008711192411252405000400026005F00280029003A003B002200210023003D002F002B003F00B7212200AE0060005E00A500AB00BB007B007D00A90024007C00B0005B005D003C003E00A300A200A10025002A005C007E00BF'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal '@&_():;"!#=/+?·™®`^¥«»{}©$|°[]<>£¢¡%*\~¿', decoded_pdu.text
      assert_equal Time.parse('2017-11-29 14:21:25 +0100'), decoded_pdu.sent
      assert_equal '+48609551253', decoded_pdu.from
      assert decoded_pdu.complete?
    end

    def test_decoding_multiline_text
      pdu = '07918497908906F0040B918406591552F300007111924183404014CCB4BB0C8A2998697719245330D3EE326806'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal "Line 1\nLine 2\nLine 3", decoded_pdu.text
      assert_equal Time.parse('2017-11-29 14:38:04 +0100'), decoded_pdu.sent
      assert_equal '+48609551253', decoded_pdu.from
      assert decoded_pdu.complete?
    end

    def test_decoding_first_multipart
      pdu = '07918497908906F0400B918406591552F30008812020415390408C050003160301015B00660064006400660067006700200064002000640064006300630063006700620068006700660064006400630063006300640066004000330034005F0023003D002F003D00280029003A003B00220077006400660066006700660066006400650065006500720074002000670064007900200079006A0020006800640020006400640063'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'śfddfgg d ddcccgbhgfddcccdf@34_#=/=():;"wdffgffdeeert gdy yj hd ddc', decoded_pdu.text
      assert_equal Time.parse('2018-02-02 14:35:09 +0100'), decoded_pdu.sent
      assert_equal '+48609551253', decoded_pdu.from
      assert_equal 22, decoded_pdu.multipart_id
      assert_equal 3, decoded_pdu.number_of_parts
      assert_equal 1, decoded_pdu.part_number
    end

    def test_decoding_middle_multipart
      pdu = '07918497908906F0400B918406591552F30008812020415390408C050003160302006800680068006600640064006300660066006600660066006700670068006800670066006400660066006700680068006A002000680064002000640063006600670068006800670066006300660066006700670067006700660066006500650065006500650065006500650065006500200073002D00660020006600660067006700620076'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'hhhfddcfffffgghhgfdffghhj hd dcfghhgfcffggggffeeeeeeeeee s-f ffggbv', decoded_pdu.text
      assert_equal Time.parse('2018-02-02 14:35:09 +0100'), decoded_pdu.sent
      assert_equal '+48609551253', decoded_pdu.from
      assert_equal 22, decoded_pdu.multipart_id
      assert_equal 3, decoded_pdu.number_of_parts
      assert_equal 2, decoded_pdu.part_number
    end

    def test_decoding_last_multipart
      pdu = '07918497908906F0440B918406591552F30008812020415301408405000316030300630064006400640064006600760068006700200063002E0064002E00200064006600660020006800200068006700660020006300640020007600680068006700660064006600660067006700660066007600670067006600640066006600680068006A006A002000680064002000660063006700680068002000630064'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'cddddfvhg c.d. dff h hgf cd vhhgfdffggffvggfdffhhjj hd fcghh cd', decoded_pdu.text
      assert_equal Time.parse('2018-02-02 14:35:10 +0100'), decoded_pdu.sent
      assert_equal '+48609551253', decoded_pdu.from
      assert_equal 22, decoded_pdu.multipart_id
      assert_equal 3, decoded_pdu.number_of_parts
      assert_equal 3, decoded_pdu.part_number
    end

    def test_decoding_production_pdu_1
      pdu = '07912470338016004404B9643000118120510104414071050003EE03036839D072CC02C1DFEB3A19847E83DC65BDBC3E4FD3CB20F87BCE0EBBD36DD0942A2D069B4F278808728741341B6CE60259D3E332C81D06DDEF7717BDD57E8BD3ECB26BAC7FCDE9F272B8FD76BB40D6F01C446D35DFE234BBAC00814020'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal Time.parse('2018-02-15 10:40:14 +0100'), decoded_pdu.sent
      assert_equal '4603', decoded_pdu.from
      assert_equal 238, decoded_pdu.multipart_id
      assert_equal 3, decoded_pdu.number_of_parts
      assert_equal 3, decoded_pdu.part_number
      assert_equal "49 Kc, pokud ho nezrusite poslanim STREAMON D na 4603. Vice na www.t-mobile.cz/streamon. Vas T-Mobile\n    ", decoded_pdu.text
    end

    def test_decoding_production_pdu_2
      pdu = '07912470338016000404B9150300008120613123634026C3696B2AA3E940D9775D0E62BFCF693768DA9C82C66F725907CAE168B1DCCD967301'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'CS-S24: Your login SMS code: 98419769.', decoded_pdu.text
      assert_equal Time.parse('2018-02-16 13:32:36 +0100'), decoded_pdu.sent
      assert_equal '5130', decoded_pdu.from
      assert decoded_pdu.complete?
    end

    def test_decoding_production_pdu_3
      pdu = '07912470338016000412D0D3751D9E7687414B2100008130109014244061CDB7BA2C0CBBD7611D082A4FA3D9E179D99D0691DFA0309C9D5E87C7E51D881CA6D7DBA030681C9EEB40B0980B3673C960311C0896D3D162BA996D070AD6E96F795A1F1EBBD3A069730A5ABFC93A50AC3603E56635'
      decoded_pdu = PduDecoder.decode(pdu)
      assert_equal 'MojeBanka: Prihlaseni do aplikace; datum a cas: 01.03.2018 09:41:36; Autorizacni SMS kod: 153 935', decoded_pdu.text
      assert_equal Time.parse('2018-03-01 09:41:42 +0100'), decoded_pdu.sent
      assert_equal 'Skupina KB', decoded_pdu.from
      assert decoded_pdu.complete?
    end
  end
end