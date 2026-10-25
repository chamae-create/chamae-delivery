module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    "ecmaVersion": 2018,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
  },
  overrides: [
    {
      files: ["delivery-pricing.js", "delivery-service.js", "delivery-pin.js",
        "customer-security.js", "customer-identity.js", "customer-account.js",
        "customer-account-state.js",
        "customer-provider-revocation.js",
        "test/customer-provider-revocation.spec.js",
        "test/customer-privacy.emulator.spec.js",
        "order-acceptance.js", "destination-country.js",
        "order-cancellation.js", "order-cancellation-state.js",
        "delivery-contingency.js", "delivery-contingency-state.js",
        "test/delivery-contingency.spec.js",
        "test/delivery-contingency.emulator.spec.js",
        "test/order-cancellation.spec.js",
        "test/order-cancellation.emulator.spec.js",
        "test/operational-fixture.js", "test/financial.spec.js",
        "test/order-acceptance.spec.js",
        "test/order-acceptance.emulator.spec.js",
        "customer-onboarding.js",
        "google-routes-provider.js",
        "test/delivery-official.spec.js", "test/customer-onboarding.spec.js",
        "test/delivery-contracts.spec.js", "test/customer-account.spec.js",
        "test/customer-account.emulator.spec.js"],
      parserOptions: {ecmaVersion: 2022},
      rules: {"require-jsdoc": "off", "max-len": ["error", {code: 120}]},
    },
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
