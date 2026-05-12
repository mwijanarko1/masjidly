// Watchman often returns EPERM on macOS (Documents, sandbox, or TCC). Metro then
// crashes even after falling back. Disable Watchman so Metro uses Node crawling.
const { getDefaultConfig } = require("expo/metro-config");

/** @type {import('expo/metro-config').MetroConfig} */
const config = getDefaultConfig(__dirname);
config.resolver.useWatchman = false;

module.exports = config;
