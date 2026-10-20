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
        "customer-security.js", "customer-identity.js",
        "customer-onboarding.js",
        "google-routes-provider.js",
        "test/delivery-official.spec.js", "test/customer-onboarding.spec.js",
        "test/delivery-contracts.spec.js"],
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
