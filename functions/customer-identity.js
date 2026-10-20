// These fields are taken from a Firebase-verified ID token, never request.data.
function verifiedCustomerToken(token = {}) {
  const provider = token.firebase?.sign_in_provider;
  return Boolean(provider && provider !== "anonymous" &&
    (token.customerVerified === true || ["google.com", "apple.com"].includes(provider)));
}
module.exports = {verifiedCustomerToken};
