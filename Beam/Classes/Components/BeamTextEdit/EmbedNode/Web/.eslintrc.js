/* eslint-env node */
module.exports = {
  root: true,
  parser: "@typescript-eslint/parser",
  plugins: [
    "@typescript-eslint"
  ],
  env: {
    browser: true
  },
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended"
  ],
  rules: {
    "@typescript-eslint/no-var-requires": ["warn"],
    "@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_", varsIgnorePattern: "^_" }],
    "@typescript-eslint/no-this-alias": ["off"],
    semi: ["warn", "never"],
    quotes: ["warn", "double"],
    "comma-dangle": ["warn", "never"]
  },
  "ignorePatterns": ["*_prod.js"]
}
