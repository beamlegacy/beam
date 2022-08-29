/* eslint-env node */
/** @type {import('ts-jest/dist/types').InitialOptionsTsJest} */
module.exports = {
  preset: "ts-jest", // preset is optional, you don't need it in case you use babel preset typescript
  testEnvironment: "jsdom", // To have access to browser objects like window or document
}
