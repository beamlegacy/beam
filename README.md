<p align="center">
  <img src="https://github.com/beamlegacy/beam/blob/main/Beam/Assets/Assets.xcassets/AppIcon.appiconset/icon_256x256.png?raw=true" height="128">
  <h1 align="center">Beam</h1>
  <p align="center"> A new way to experience the Internet.</p>
</p>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/assets/mainwindow_dark_optimized.png?raw=true">
  <source media="(prefers-color-scheme: light)" srcset=".github/assets/mainwindow_light_optimized.png?raw=true">
  <img alt="Beam Browser Preview" src=".github/assets/mainwindow_light_optimized.png?raw=true">
</picture>

<p align="center">
  <a href="https://www.dropbox.com/s/gwliqsubg64oaf1/Beam.dmg?dl=1">
    <img src=".github/assets/download_button.png?raw=true" width="160">
    </a>
</p>

<!-- omit in toc -->
## Table of Contents
- [🚀 Getting Started](#-getting-started)
  - [🔧 Setup](#-setup)
  - [🩺 Tests](#-tests)
  - [⌨️ Development](#️-development)
  - [🌐 Web Components](#-web-components)
- [👨‍💻 Contributors](#-contributors)
- [📖 License](#-license)


## 🚀 Getting Started 

> [!IMPORTANT]
> The official development of **beam** macOS app [has stopped in November 2022](https://twitter.com/getonbeam/status/1592134355371331585). Because the app is still used by some of us, and we still believe in a webkit-based ML-powered browser + note editor. We decided to open source it. This is still far from done, please reach out if you want to contribute [TBD]

Pull Requests with bug fixes and new features are much appreciated. We will be happy to review them and merge it once ready. If you have suggestions or want to report bugs please open an [issue](https://github.com/beamlegacy/beam/issues).

Our current focus is making the project build and run in debug mode, locally from Xcode.

### 🔧 Setup
Start by cloning the repo:
```shell
git clone git@github.com:beamlegacy/beam.git
```
Go inside the project inside the project:
```
cd beam
``` 
Run the setup script with:
```
make setup
```

### 🩺 Tests

TBD - Checkout README_previous.md to see old instructions.

### ⌨️ Development

TBD - The process

### 🌐 Web Components
Run `yarn generate` to use the CLI wizard to generate a preconfigured TS component. Then add the newly created message handler to the browsertab at BrowserTab.swift#83. Add simple example component to follow is the MediaPlayerMessageHandler.


## 👨‍💻 Contributors

TBD 

## 📖 License

TBD