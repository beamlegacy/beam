const { generateTemplateFiles } = require("generate-template-files")

generateTemplateFiles([
  {
    option: "Create Web Component",
    defaultCase: "(pascalCase)",
    entry: {
      folderPath: "./generator/templates/WebComponent"
    },
    stringReplacers: ["__component_name__"],
    output: {
      path: "Beam/Classes/Components/__component_name__",
      pathAndFileNameDefaultCase: "(pascalCase)"
    },
    onComplete: (results) => {
      console.log("⚠️ Don't forget to add the files in Xcode")
    }
  },
  {
    option: "Create Web Package",
    defaultCase: "(pascalCase)",
    entry: {
      folderPath: "./generator/templates/WebPackage"
    },
    stringReplacers: ["__package_name__"],
    output: {
      path: "Beam/Classes/Helpers/Utils/Web/__package_name__",
      pathAndFileNameDefaultCase: "(pascalCase)"
    },
    onComplete: (results) => {
      console.log("⚠️ Don't forget to add the files in Xcode")
    }
  }
])
