module.exports = {
  env: {
    browser: true,
    node: true,
    es2021: true,
  },
  extends: ["eslint:recommended", "prettier"],
  globals: {
    global: "writable",
  },
  parserOptions: {
    ecmaVersion: 12,
    sourceType: "module",
  },
}
