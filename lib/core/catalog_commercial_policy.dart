/// Commercial visibility only. Never use this to filter historical order items.
String _commercialText(Object? value) => (value ?? '')
    .toString()
    .toLowerCase()
    .replaceAll(RegExp('[áàâãä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòôõö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp('[^a-z0-9]+'), ' ')
    .trim();

bool isCommerciallyBlocked(Map<String, dynamic> product) {
  if (product['commercialBlocked'] == true) return true;
  final text =
      '${_commercialText(product['name'])} ${_commercialText(product['category'])}';
  return RegExp(
              r'\b(pods?|vapes?|vaping|cigarros?|cigarrilhos?|tabaco|tabacos|tabacaria|nicotina|nicotine|narguile|narguiles)\b')
          .hasMatch(text) ||
      RegExp(r'\b(marlboro|dunhill|rothmans|pall mall|lucky strike|gudang garam|elf bar|elfbar|lost mary)\b')
          .hasMatch(text) ||
      RegExp(r'\bignite v[0-9]+\b').hasMatch(text);
}
