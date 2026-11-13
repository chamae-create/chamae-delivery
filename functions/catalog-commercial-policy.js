// Commercial visibility only; never rewrite historical items.
const registry = require("./catalog-commercial-registry.json");
/** Normalizes a commercial label.
 * @param {*} value Label.
 * @return {string} Canonical label.
 */
function commercialText(value) {
  return String(value == null ? "" : value).normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "").toLowerCase()
      .replace(/[^a-z0-9]+/g, " ").trim();
}
/** Flattens category metadata without trusting an activation flag.
 * @param {*} value Category metadata.
 * @return {string[]} Labels or identities.
 */
function categoryLeaves(value) {
  if (value == null) return [];
  if (Array.isArray(value)) return value.flatMap(categoryLeaves);
  if (typeof value === "object") {
    return Object.values(value).flatMap(categoryLeaves);
  }
  return [String(value)];
}
/** Reads category metadata relevant to restrictions.
 * @param {Object} product Official product metadata.
 * @param {string[]} keys Category fields.
 * @return {string[]} Metadata leaves.
 */
function categoryFields(product, keys) {
  return keys.flatMap((key) => categoryLeaves(product[key]));
}
const labelKeys = ["category", "subcategory", "parentCategory",
  "categoryPath", "categories"];
const idKeys = ["categoryId", "subcategoryId", "parentCategoryId"];
/** Denies immutable restricted IDs, descendants, aliases and explicit blocks.
 * @param {Object} product Official product data, with server-supplied id.
 * @return {boolean} Whether commercial exposure is prohibited.
 */
function isCommerciallyBlocked(product = {}) {
  if (product.commercialBlocked === true ||
      registry.restrictedProductIds.includes(String(product.id || "")) ||
      categoryFields(product, idKeys)
          .some((id) => registry.restrictedCategoryIds.includes(id))) {
    return true;
  }
  const labels = categoryFields(product, labelKeys);
  const text = commercialText([product.name || "", ...labels].join(" "));
  return new RegExp(registry.restrictedPattern).test(text);
}
/** Fails closed on unknown category classifications for new sales.
 * @param {Object} product Official product metadata.
 * @return {boolean} Whether classification requires human review.
 */
function categoryReviewRequired(product = {}) {
  const labels = categoryFields(product, labelKeys);
  const ids = categoryFields(product, idKeys);
  return labels.length + ids.length === 0 ||
    labels.some((x) => !registry.allowedCategoryNames
        .includes(commercialText(x))) ||
    ids.some((x) => !registry.allowedCategoryNames
        .includes(registry.categoryNamesById[x]));
}
/** Preserves the existing GranCheff go-live block.
 * @param {Object} product Official product data.
 * @return {?string} Blocking reason.
 */
function integratedCommercialBlockReason(product = {}) {
  return product.PRO_CODIGO != null ?
    "GRANCHEFF_COMMERCIAL_RELEASE_PENDING" : null;
}
module.exports = {isCommerciallyBlocked, categoryReviewRequired,
  integratedCommercialBlockReason};
