## WebPackMiniS

![Swift3](https://img.shields.io/badge/swift-3-blue.svg)
![tuxOS](https://img.shields.io/badge/os-tuxOS-green.svg?style=flat)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Travis](https://travis-ci.org/AlwaysRightInstitute/WebPackMiniS.svg?branch=develop)

This is a tiny version of the
[webpack](https://webpack.js.org/)
JavaScript bundler, but written in Swift.

The sole purpose is to get some basic packing and JavaScript
module management functionality for server side Swift 
applications.
Without having to download the whole NPM/webpack infrastructure
(you know, `du -sh node_modules` => `82M` ...)

**Note**: This is only intended for very simple development setups!
Using the real
[webpack](https://webpack.js.org/)
is still recommended for generating deployment bundles.
And actually even for serious JS frontend development. The real
[webpack](https://webpack.js.org/)
provides hot-reloads and such, which are super convenient
(but require the webpack dev server to run alongside your
 server side Swift application).
 
### Supported Features

[webpack](https://webpack.js.org/) has literally tons of features and this
supports very little of them :-)

What this does support:

- transpile of some ES6 `import` and `export` statements
- a hackish Vue loader, doesn't compile like the real loader and lacks
  tons of other features
- import of CSS into inline JS


### Status

This is a very hackish setup, but seems to work well enough
for our purposes so far :-)

### Who

**WebPackMiniS** is brought to you by
[ZeeZide](http://zeezide.de).
We like feedback, GitHub stars, cool contract work,
presumably any form of praise you can think of.

Join us in the [Noze.io Slack](http://slack.noze.io).
