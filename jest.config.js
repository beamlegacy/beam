/* eslint-env node */
/** @type {import('ts-jest/dist/types').InitialOptionsTsJest} */

// yarn workspaces list --json | jq --slurp .  

const workspaces = require("./yarn-workspaces.json")

let projects = [] 

workspaces.forEach(({name, location}) => {
  // Skip root directory
  if (location == ".") return

  // Add to projects array
  projects.push({
    testEnvironment: "jsdom",
    preset: "ts-jest",
    displayName: name,
    testMatch: [`<rootDir>${location}/tests/**/*.test.ts`]
  })
})

module.exports = {
  verbose: true,
  silent: true,
  reporters: [ "default", "jest-junit" ],
  projects
}
