// Kept identical to the backend policy. Visibility never changes order history.
/** Normalizes a catalog value without changing nullish handling.
 * @param {*} value Catalog field.
 * @return {string} Normalized text.
 */
function commercialText(value) {
  return String(value === null || value === undefined ? "" : value)
      .normalize("NFD").replace(/[\u0300-\u036f]/g, "")
      .toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}
/** Checks the existing commercial exclusion policy.
 * @param {Object} product Official product data.
 * @return {boolean} Whether the product is commercially blocked.
 */
function isCommerciallyBlocked(product = {}) {
  if (product.commercialBlocked === true) return true;
  const text =
      `${commercialText(product.name)} ${commercialText(product.category)}`;
  return new RegExp(
      "\\b(pods?|vapes?|vaping|cigarros?|cigarrilhos?|tabaco|tabacos|" +
      "tabacaria|nicotina|nicotine|narguile|narguiles)\\b",
  ).test(text) ||
    new RegExp(
        "\\b(marlboro|dunhill|rothmans|pall mall|lucky strike|" +
        "gudang garam|elf bar|elfbar|lost mary)\\b",
    ).test(text) ||
    /\bignite v[0-9]+\b/.test(text);
}
module.exports = {isCommerciallyBlocked};
