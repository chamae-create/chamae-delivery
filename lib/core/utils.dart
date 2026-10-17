class PixUtils {
  // Gera o payload padrão oficial do Banco Central do Brasil (EMVCo)
  static String gerarPayloadPix({
    required String chavePix,
    required String nomeRecebedor,
    required String cidadeRecebedor,
    required double valor,
    required String txId,
  }) {
    String formatField(String id, String value) {
      final len = value.length.toString().padLeft(2, '0');
      return '$id$len$value';
    }

    final valorStr = valor.toStringAsFixed(2);
    final chaveFormatted = formatField('01', chavePix);
    final merchantAccountInfo = formatField('00', 'br.gov.bcb.pix') + chaveFormatted;

    String payload = '000201${formatField('26', merchantAccountInfo)}${formatField('52', '0000')}${formatField('53', '986')}${formatField('54', valorStr)}${formatField('58', 'BR')}${formatField('59', nomeRecebedor.toUpperCase())}${formatField('60', cidadeRecebedor.toUpperCase())}${formatField('62', formatField('05', txId))}6304';

    final crc = _calcularCRC16(payload);
    return payload + crc;
  }

  // Algoritmo CRC-16-CCITT (0xFFFF) exigido pelo Banco Central
  static String _calcularCRC16(String str) {
    int crc = 0xFFFF;
    for (int i = 0; i < str.length; i++) {
      crc ^= (str.codeUnitAt(i) << 8);
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
class AppStrings {
  static String get(String key, String language) {
    const pt = {
      'name': 'Nome completo',
      'social_name': 'Nome social',
      'whatsapp': 'WhatsApp',
      'doc_br': 'CPF',
      'doc_py': 'Cédula de Identidade',
    };

    return pt[key] ?? key;
  }
}