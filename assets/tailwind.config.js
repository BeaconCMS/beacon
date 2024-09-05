// Tailwind config for Beacon Sites
//
// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")
// FIXME: enable heroicons plugin
// const fs = require("fs")
// const path = require("path")

export default {
  content: [],
  theme: {
    extend: {},
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography"),

    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({ addVariant }) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({ addVariant }) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({ addVariant }) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),

    // Embeds Heroicons (https://heroicons.com) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    //
    // plugin(function ({ matchComponents, theme }) {
    //   let values = {}
    //   let iconsDir = null

    //   // Copy from host app deps.
    //   let hostIconsDir = path.join(__dirname, "../../heroicons/optimized")

    //   // Copy from release.
    //   // Adjust for Umbrella apps. See the Heroicons guide for more info.
    //   let releaseIconsDir = path.join(__dirname, "../../../vendor/heroicons/optimized")

    //   if (fs.existsSync(hostIconsDir)) {
    //     iconsDir = hostIconsDir
    //   } else if (fs.existsSync(releaseIconsDir)) {
    //     iconsDir = releaseIconsDir
    //   } else {
    //     return matchComponents({ hero: ({ _name, _fullPath }) => {} }, { values })
    //   }

    //   let icons = [
    //     ["", "/24/outline"],
    //     ["-solid", "/24/solid"],
    //     ["-mini", "/20/solid"],
    //     ["-micro", "/16/solid"],
    //   ]
    //   icons.forEach(([suffix, dir]) => {
    //     fs.readdirSync(path.join(iconsDir, dir)).forEach((file) => {
    //       let name = path.basename(file, ".svg") + suffix
    //       values[name] = { name, fullPath: path.join(iconsDir, dir, file) }
    //     })
    //   })
    //   matchComponents(
    //     {
    //       hero: ({ name, fullPath }) => {
    //         let content = fs
    //           .readFileSync(fullPath)
    //           .toString()
    //           .replace(/\r?\n|\r/g, "")
    //         let size = theme("spacing.6")
    //         if (name.endsWith("-mini")) {
    //           size = theme("spacing.5")
    //         } else if (name.endsWith("-micro")) {
    //           size = theme("spacing.4")
    //         }
    //         return {
    //           [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
    //           "-webkit-mask": `var(--hero-${name})`,
    //           mask: `var(--hero-${name})`,
    //           "mask-repeat": "no-repeat",
    //           "background-color": "currentColor",
    //           "vertical-align": "middle",
    //           display: "inline-block",
    //           width: size,
    //           height: size,
    //         }
    //       },
    //     },
    //     { values },
    //   )
    // }),
  ],
}
