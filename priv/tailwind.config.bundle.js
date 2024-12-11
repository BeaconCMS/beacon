var __getOwnPropNames = Object.getOwnPropertyNames;
var __commonJS = (cb, mod) => function __require() {
  return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
};

// node_modules/tailwindcss/lib/util/createPlugin.js
var require_createPlugin = __commonJS({
  "node_modules/tailwindcss/lib/util/createPlugin.js"(exports) {
    "use strict";
    Object.defineProperty(exports, "__esModule", {
      value: true
    });
    Object.defineProperty(exports, "default", {
      enumerable: true,
      get: function() {
        return _default;
      }
    });
    function createPlugin(plugin2, config) {
      return {
        handler: plugin2,
        config
      };
    }
    createPlugin.withOptions = function(pluginFunction, configFunction = () => ({})) {
      const optionsFunction = function(options) {
        return {
          __options: options,
          handler: pluginFunction(options),
          config: configFunction(options)
        };
      };
      optionsFunction.__isOptionsFunction = true;
      optionsFunction.__pluginFunction = pluginFunction;
      optionsFunction.__configFunction = configFunction;
      return optionsFunction;
    };
    var _default = createPlugin;
  }
});

// node_modules/tailwindcss/lib/public/create-plugin.js
var require_create_plugin = __commonJS({
  "node_modules/tailwindcss/lib/public/create-plugin.js"(exports) {
    "use strict";
    Object.defineProperty(exports, "__esModule", {
      value: true
    });
    Object.defineProperty(exports, "default", {
      enumerable: true,
      get: function() {
        return _default;
      }
    });
    var _createPlugin = /* @__PURE__ */ _interop_require_default(require_createPlugin());
    function _interop_require_default(obj) {
      return obj && obj.__esModule ? obj : {
        default: obj
      };
    }
    var _default = _createPlugin.default;
  }
});

// node_modules/tailwindcss/plugin.js
var require_plugin = __commonJS({
  "node_modules/tailwindcss/plugin.js"(exports, module) {
    var createPlugin = require_create_plugin();
    module.exports = (createPlugin.__esModule ? createPlugin : { default: createPlugin }).default;
  }
});

// node_modules/mini-svg-data-uri/shorter-css-color-names.js
var require_shorter_css_color_names = __commonJS({
  "node_modules/mini-svg-data-uri/shorter-css-color-names.js"(exports, module) {
    module.exports = {
      aqua: /#00ffff(ff)?(?!\w)|#0ff(f)?(?!\w)/gi,
      azure: /#f0ffff(ff)?(?!\w)/gi,
      beige: /#f5f5dc(ff)?(?!\w)/gi,
      bisque: /#ffe4c4(ff)?(?!\w)/gi,
      black: /#000000(ff)?(?!\w)|#000(f)?(?!\w)/gi,
      blue: /#0000ff(ff)?(?!\w)|#00f(f)?(?!\w)/gi,
      brown: /#a52a2a(ff)?(?!\w)/gi,
      coral: /#ff7f50(ff)?(?!\w)/gi,
      cornsilk: /#fff8dc(ff)?(?!\w)/gi,
      crimson: /#dc143c(ff)?(?!\w)/gi,
      cyan: /#00ffff(ff)?(?!\w)|#0ff(f)?(?!\w)/gi,
      darkblue: /#00008b(ff)?(?!\w)/gi,
      darkcyan: /#008b8b(ff)?(?!\w)/gi,
      darkgrey: /#a9a9a9(ff)?(?!\w)/gi,
      darkred: /#8b0000(ff)?(?!\w)/gi,
      deeppink: /#ff1493(ff)?(?!\w)/gi,
      dimgrey: /#696969(ff)?(?!\w)/gi,
      gold: /#ffd700(ff)?(?!\w)/gi,
      green: /#008000(ff)?(?!\w)/gi,
      grey: /#808080(ff)?(?!\w)/gi,
      honeydew: /#f0fff0(ff)?(?!\w)/gi,
      hotpink: /#ff69b4(ff)?(?!\w)/gi,
      indigo: /#4b0082(ff)?(?!\w)/gi,
      ivory: /#fffff0(ff)?(?!\w)/gi,
      khaki: /#f0e68c(ff)?(?!\w)/gi,
      lavender: /#e6e6fa(ff)?(?!\w)/gi,
      lime: /#00ff00(ff)?(?!\w)|#0f0(f)?(?!\w)/gi,
      linen: /#faf0e6(ff)?(?!\w)/gi,
      maroon: /#800000(ff)?(?!\w)/gi,
      moccasin: /#ffe4b5(ff)?(?!\w)/gi,
      navy: /#000080(ff)?(?!\w)/gi,
      oldlace: /#fdf5e6(ff)?(?!\w)/gi,
      olive: /#808000(ff)?(?!\w)/gi,
      orange: /#ffa500(ff)?(?!\w)/gi,
      orchid: /#da70d6(ff)?(?!\w)/gi,
      peru: /#cd853f(ff)?(?!\w)/gi,
      pink: /#ffc0cb(ff)?(?!\w)/gi,
      plum: /#dda0dd(ff)?(?!\w)/gi,
      purple: /#800080(ff)?(?!\w)/gi,
      red: /#ff0000(ff)?(?!\w)|#f00(f)?(?!\w)/gi,
      salmon: /#fa8072(ff)?(?!\w)/gi,
      seagreen: /#2e8b57(ff)?(?!\w)/gi,
      seashell: /#fff5ee(ff)?(?!\w)/gi,
      sienna: /#a0522d(ff)?(?!\w)/gi,
      silver: /#c0c0c0(ff)?(?!\w)/gi,
      skyblue: /#87ceeb(ff)?(?!\w)/gi,
      snow: /#fffafa(ff)?(?!\w)/gi,
      tan: /#d2b48c(ff)?(?!\w)/gi,
      teal: /#008080(ff)?(?!\w)/gi,
      thistle: /#d8bfd8(ff)?(?!\w)/gi,
      tomato: /#ff6347(ff)?(?!\w)/gi,
      violet: /#ee82ee(ff)?(?!\w)/gi,
      wheat: /#f5deb3(ff)?(?!\w)/gi,
      white: /#ffffff(ff)?(?!\w)|#fff(f)?(?!\w)/gi
    };
  }
});

// node_modules/mini-svg-data-uri/index.js
var require_mini_svg_data_uri = __commonJS({
  "node_modules/mini-svg-data-uri/index.js"(exports, module) {
    var shorterNames = require_shorter_css_color_names();
    var REGEX = {
      whitespace: /\s+/g,
      urlHexPairs: /%[\dA-F]{2}/g,
      quotes: /"/g
    };
    function collapseWhitespace(str) {
      return str.trim().replace(REGEX.whitespace, " ");
    }
    function dataURIPayload(string) {
      return encodeURIComponent(string).replace(REGEX.urlHexPairs, specialHexEncode);
    }
    function colorCodeToShorterNames(string) {
      Object.keys(shorterNames).forEach(function(key) {
        if (shorterNames[key].test(string)) {
          string = string.replace(shorterNames[key], key);
        }
      });
      return string;
    }
    function specialHexEncode(match) {
      switch (match) {
        case "%20":
          return " ";
        case "%3D":
          return "=";
        case "%3A":
          return ":";
        case "%2F":
          return "/";
        default:
          return match.toLowerCase();
      }
    }
    function svgToTinyDataUri(svgString) {
      if (typeof svgString !== "string") {
        throw new TypeError("Expected a string, but received " + typeof svgString);
      }
      if (svgString.charCodeAt(0) === 65279) {
        svgString = svgString.slice(1);
      }
      var body = colorCodeToShorterNames(collapseWhitespace(svgString)).replace(REGEX.quotes, "'");
      return "data:image/svg+xml," + dataURIPayload(body);
    }
    svgToTinyDataUri.toSrcset = function toSrcset(svgString) {
      return svgToTinyDataUri(svgString).replace(/ /g, "%20");
    };
    module.exports = svgToTinyDataUri;
  }
});

// node_modules/tailwindcss/lib/util/cloneDeep.js
var require_cloneDeep = __commonJS({
  "node_modules/tailwindcss/lib/util/cloneDeep.js"(exports) {
    "use strict";
    Object.defineProperty(exports, "__esModule", {
      value: true
    });
    Object.defineProperty(exports, "cloneDeep", {
      enumerable: true,
      get: function() {
        return cloneDeep;
      }
    });
    function cloneDeep(value) {
      if (Array.isArray(value)) {
        return value.map((child) => cloneDeep(child));
      }
      if (typeof value === "object" && value !== null) {
        return Object.fromEntries(Object.entries(value).map(([k, v]) => [
          k,
          cloneDeep(v)
        ]));
      }
      return value;
    }
  }
});

// node_modules/tailwindcss/stubs/config.full.js
var require_config_full = __commonJS({
  "node_modules/tailwindcss/stubs/config.full.js"(exports, module) {
    module.exports = {
      content: [],
      presets: [],
      darkMode: "media",
      // or 'class'
      theme: {
        accentColor: ({ theme }) => ({
          ...theme("colors"),
          auto: "auto"
        }),
        animation: {
          none: "none",
          spin: "spin 1s linear infinite",
          ping: "ping 1s cubic-bezier(0, 0, 0.2, 1) infinite",
          pulse: "pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite",
          bounce: "bounce 1s infinite"
        },
        aria: {
          busy: 'busy="true"',
          checked: 'checked="true"',
          disabled: 'disabled="true"',
          expanded: 'expanded="true"',
          hidden: 'hidden="true"',
          pressed: 'pressed="true"',
          readonly: 'readonly="true"',
          required: 'required="true"',
          selected: 'selected="true"'
        },
        aspectRatio: {
          auto: "auto",
          square: "1 / 1",
          video: "16 / 9"
        },
        backdropBlur: ({ theme }) => theme("blur"),
        backdropBrightness: ({ theme }) => theme("brightness"),
        backdropContrast: ({ theme }) => theme("contrast"),
        backdropGrayscale: ({ theme }) => theme("grayscale"),
        backdropHueRotate: ({ theme }) => theme("hueRotate"),
        backdropInvert: ({ theme }) => theme("invert"),
        backdropOpacity: ({ theme }) => theme("opacity"),
        backdropSaturate: ({ theme }) => theme("saturate"),
        backdropSepia: ({ theme }) => theme("sepia"),
        backgroundColor: ({ theme }) => theme("colors"),
        backgroundImage: {
          none: "none",
          "gradient-to-t": "linear-gradient(to top, var(--tw-gradient-stops))",
          "gradient-to-tr": "linear-gradient(to top right, var(--tw-gradient-stops))",
          "gradient-to-r": "linear-gradient(to right, var(--tw-gradient-stops))",
          "gradient-to-br": "linear-gradient(to bottom right, var(--tw-gradient-stops))",
          "gradient-to-b": "linear-gradient(to bottom, var(--tw-gradient-stops))",
          "gradient-to-bl": "linear-gradient(to bottom left, var(--tw-gradient-stops))",
          "gradient-to-l": "linear-gradient(to left, var(--tw-gradient-stops))",
          "gradient-to-tl": "linear-gradient(to top left, var(--tw-gradient-stops))"
        },
        backgroundOpacity: ({ theme }) => theme("opacity"),
        backgroundPosition: {
          bottom: "bottom",
          center: "center",
          left: "left",
          "left-bottom": "left bottom",
          "left-top": "left top",
          right: "right",
          "right-bottom": "right bottom",
          "right-top": "right top",
          top: "top"
        },
        backgroundSize: {
          auto: "auto",
          cover: "cover",
          contain: "contain"
        },
        blur: {
          0: "0",
          none: "",
          sm: "4px",
          DEFAULT: "8px",
          md: "12px",
          lg: "16px",
          xl: "24px",
          "2xl": "40px",
          "3xl": "64px"
        },
        borderColor: ({ theme }) => ({
          ...theme("colors"),
          DEFAULT: theme("colors.gray.200", "currentColor")
        }),
        borderOpacity: ({ theme }) => theme("opacity"),
        borderRadius: {
          none: "0px",
          sm: "0.125rem",
          DEFAULT: "0.25rem",
          md: "0.375rem",
          lg: "0.5rem",
          xl: "0.75rem",
          "2xl": "1rem",
          "3xl": "1.5rem",
          full: "9999px"
        },
        borderSpacing: ({ theme }) => ({
          ...theme("spacing")
        }),
        borderWidth: {
          DEFAULT: "1px",
          0: "0px",
          2: "2px",
          4: "4px",
          8: "8px"
        },
        boxShadow: {
          sm: "0 1px 2px 0 rgb(0 0 0 / 0.05)",
          DEFAULT: "0 1px 3px 0 rgb(0 0 0 / 0.1), 0 1px 2px -1px rgb(0 0 0 / 0.1)",
          md: "0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)",
          lg: "0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)",
          xl: "0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1)",
          "2xl": "0 25px 50px -12px rgb(0 0 0 / 0.25)",
          inner: "inset 0 2px 4px 0 rgb(0 0 0 / 0.05)",
          none: "none"
        },
        boxShadowColor: ({ theme }) => theme("colors"),
        brightness: {
          0: "0",
          50: ".5",
          75: ".75",
          90: ".9",
          95: ".95",
          100: "1",
          105: "1.05",
          110: "1.1",
          125: "1.25",
          150: "1.5",
          200: "2"
        },
        caretColor: ({ theme }) => theme("colors"),
        colors: ({ colors }) => ({
          inherit: colors.inherit,
          current: colors.current,
          transparent: colors.transparent,
          black: colors.black,
          white: colors.white,
          slate: colors.slate,
          gray: colors.gray,
          zinc: colors.zinc,
          neutral: colors.neutral,
          stone: colors.stone,
          red: colors.red,
          orange: colors.orange,
          amber: colors.amber,
          yellow: colors.yellow,
          lime: colors.lime,
          green: colors.green,
          emerald: colors.emerald,
          teal: colors.teal,
          cyan: colors.cyan,
          sky: colors.sky,
          blue: colors.blue,
          indigo: colors.indigo,
          violet: colors.violet,
          purple: colors.purple,
          fuchsia: colors.fuchsia,
          pink: colors.pink,
          rose: colors.rose
        }),
        columns: {
          auto: "auto",
          1: "1",
          2: "2",
          3: "3",
          4: "4",
          5: "5",
          6: "6",
          7: "7",
          8: "8",
          9: "9",
          10: "10",
          11: "11",
          12: "12",
          "3xs": "16rem",
          "2xs": "18rem",
          xs: "20rem",
          sm: "24rem",
          md: "28rem",
          lg: "32rem",
          xl: "36rem",
          "2xl": "42rem",
          "3xl": "48rem",
          "4xl": "56rem",
          "5xl": "64rem",
          "6xl": "72rem",
          "7xl": "80rem"
        },
        container: {},
        content: {
          none: "none"
        },
        contrast: {
          0: "0",
          50: ".5",
          75: ".75",
          100: "1",
          125: "1.25",
          150: "1.5",
          200: "2"
        },
        cursor: {
          auto: "auto",
          default: "default",
          pointer: "pointer",
          wait: "wait",
          text: "text",
          move: "move",
          help: "help",
          "not-allowed": "not-allowed",
          none: "none",
          "context-menu": "context-menu",
          progress: "progress",
          cell: "cell",
          crosshair: "crosshair",
          "vertical-text": "vertical-text",
          alias: "alias",
          copy: "copy",
          "no-drop": "no-drop",
          grab: "grab",
          grabbing: "grabbing",
          "all-scroll": "all-scroll",
          "col-resize": "col-resize",
          "row-resize": "row-resize",
          "n-resize": "n-resize",
          "e-resize": "e-resize",
          "s-resize": "s-resize",
          "w-resize": "w-resize",
          "ne-resize": "ne-resize",
          "nw-resize": "nw-resize",
          "se-resize": "se-resize",
          "sw-resize": "sw-resize",
          "ew-resize": "ew-resize",
          "ns-resize": "ns-resize",
          "nesw-resize": "nesw-resize",
          "nwse-resize": "nwse-resize",
          "zoom-in": "zoom-in",
          "zoom-out": "zoom-out"
        },
        divideColor: ({ theme }) => theme("borderColor"),
        divideOpacity: ({ theme }) => theme("borderOpacity"),
        divideWidth: ({ theme }) => theme("borderWidth"),
        dropShadow: {
          sm: "0 1px 1px rgb(0 0 0 / 0.05)",
          DEFAULT: ["0 1px 2px rgb(0 0 0 / 0.1)", "0 1px 1px rgb(0 0 0 / 0.06)"],
          md: ["0 4px 3px rgb(0 0 0 / 0.07)", "0 2px 2px rgb(0 0 0 / 0.06)"],
          lg: ["0 10px 8px rgb(0 0 0 / 0.04)", "0 4px 3px rgb(0 0 0 / 0.1)"],
          xl: ["0 20px 13px rgb(0 0 0 / 0.03)", "0 8px 5px rgb(0 0 0 / 0.08)"],
          "2xl": "0 25px 25px rgb(0 0 0 / 0.15)",
          none: "0 0 #0000"
        },
        fill: ({ theme }) => ({
          none: "none",
          ...theme("colors")
        }),
        flex: {
          1: "1 1 0%",
          auto: "1 1 auto",
          initial: "0 1 auto",
          none: "none"
        },
        flexBasis: ({ theme }) => ({
          auto: "auto",
          ...theme("spacing"),
          "1/2": "50%",
          "1/3": "33.333333%",
          "2/3": "66.666667%",
          "1/4": "25%",
          "2/4": "50%",
          "3/4": "75%",
          "1/5": "20%",
          "2/5": "40%",
          "3/5": "60%",
          "4/5": "80%",
          "1/6": "16.666667%",
          "2/6": "33.333333%",
          "3/6": "50%",
          "4/6": "66.666667%",
          "5/6": "83.333333%",
          "1/12": "8.333333%",
          "2/12": "16.666667%",
          "3/12": "25%",
          "4/12": "33.333333%",
          "5/12": "41.666667%",
          "6/12": "50%",
          "7/12": "58.333333%",
          "8/12": "66.666667%",
          "9/12": "75%",
          "10/12": "83.333333%",
          "11/12": "91.666667%",
          full: "100%"
        }),
        flexGrow: {
          0: "0",
          DEFAULT: "1"
        },
        flexShrink: {
          0: "0",
          DEFAULT: "1"
        },
        fontFamily: {
          sans: [
            "ui-sans-serif",
            "system-ui",
            "sans-serif",
            '"Apple Color Emoji"',
            '"Segoe UI Emoji"',
            '"Segoe UI Symbol"',
            '"Noto Color Emoji"'
          ],
          serif: ["ui-serif", "Georgia", "Cambria", '"Times New Roman"', "Times", "serif"],
          mono: [
            "ui-monospace",
            "SFMono-Regular",
            "Menlo",
            "Monaco",
            "Consolas",
            '"Liberation Mono"',
            '"Courier New"',
            "monospace"
          ]
        },
        fontSize: {
          xs: ["0.75rem", { lineHeight: "1rem" }],
          sm: ["0.875rem", { lineHeight: "1.25rem" }],
          base: ["1rem", { lineHeight: "1.5rem" }],
          lg: ["1.125rem", { lineHeight: "1.75rem" }],
          xl: ["1.25rem", { lineHeight: "1.75rem" }],
          "2xl": ["1.5rem", { lineHeight: "2rem" }],
          "3xl": ["1.875rem", { lineHeight: "2.25rem" }],
          "4xl": ["2.25rem", { lineHeight: "2.5rem" }],
          "5xl": ["3rem", { lineHeight: "1" }],
          "6xl": ["3.75rem", { lineHeight: "1" }],
          "7xl": ["4.5rem", { lineHeight: "1" }],
          "8xl": ["6rem", { lineHeight: "1" }],
          "9xl": ["8rem", { lineHeight: "1" }]
        },
        fontWeight: {
          thin: "100",
          extralight: "200",
          light: "300",
          normal: "400",
          medium: "500",
          semibold: "600",
          bold: "700",
          extrabold: "800",
          black: "900"
        },
        gap: ({ theme }) => theme("spacing"),
        gradientColorStops: ({ theme }) => theme("colors"),
        gradientColorStopPositions: {
          "0%": "0%",
          "5%": "5%",
          "10%": "10%",
          "15%": "15%",
          "20%": "20%",
          "25%": "25%",
          "30%": "30%",
          "35%": "35%",
          "40%": "40%",
          "45%": "45%",
          "50%": "50%",
          "55%": "55%",
          "60%": "60%",
          "65%": "65%",
          "70%": "70%",
          "75%": "75%",
          "80%": "80%",
          "85%": "85%",
          "90%": "90%",
          "95%": "95%",
          "100%": "100%"
        },
        grayscale: {
          0: "0",
          DEFAULT: "100%"
        },
        gridAutoColumns: {
          auto: "auto",
          min: "min-content",
          max: "max-content",
          fr: "minmax(0, 1fr)"
        },
        gridAutoRows: {
          auto: "auto",
          min: "min-content",
          max: "max-content",
          fr: "minmax(0, 1fr)"
        },
        gridColumn: {
          auto: "auto",
          "span-1": "span 1 / span 1",
          "span-2": "span 2 / span 2",
          "span-3": "span 3 / span 3",
          "span-4": "span 4 / span 4",
          "span-5": "span 5 / span 5",
          "span-6": "span 6 / span 6",
          "span-7": "span 7 / span 7",
          "span-8": "span 8 / span 8",
          "span-9": "span 9 / span 9",
          "span-10": "span 10 / span 10",
          "span-11": "span 11 / span 11",
          "span-12": "span 12 / span 12",
          "span-full": "1 / -1"
        },
        gridColumnEnd: {
          auto: "auto",
          1: "1",
          2: "2",
          3: "3",
          4: "4",
          5: "5",
          6: "6",
          7: "7",
          8: "8",
          9: "9",
          10: "10",
          11: "11",
          12: "12",
          13: "13"
        },
        gridColumnStart: {
          auto: "auto",
          1: "1",
          2: "2",
          3: "3",
          4: "4",
          5: "5",
          6: "6",
          7: "7",
          8: "8",
          9: "9",
          10: "10",
          11: "11",
          12: "12",
          13: "13"
        },
        gridRow: {
          auto: "auto",
          "span-1": "span 1 / span 1",
          "span-2": "span 2 / span 2",
          "span-3": "span 3 / span 3",
          "span-4": "span 4 / span 4",
          "span-5": "span 5 / span 5",
          "span-6": "span 6 / span 6",
          "span-7": "span 7 / span 7",
          "span-8": "span 8 / span 8",
          "span-9": "span 9 / span 9",
          "span-10": "span 10 / span 10",
          "span-11": "span 11 / span 11",
          "span-12": "span 12 / span 12",
          "span-full": "1 / -1"
        },
        gridRowEnd: {
          auto: "auto",
          1: "1",
          2: "2",
          3: "3",
          4: "4",
          5: "5",
          6: "6",
          7: "7",
          8: "8",
          9: "9",
          10: "10",
          11: "11",
          12: "12",
          13: "13"
        },
        gridRowStart: {
          auto: "auto",
          1: "1",
          2: "2",
          3: "3",
          4: "4",
          5: "5",
          6: "6",
          7: "7",
          8: "8",
          9: "9",
          10: "10",
          11: "11",
          12: "12",
          13: "13"
        },
        gridTemplateColumns: {
          none: "none",
          subgrid: "subgrid",
          1: "repeat(1, minmax(0, 1fr))",
          2: "repeat(2, minmax(0, 1fr))",
          3: "repeat(3, minmax(0, 1fr))",
          4: "repeat(4, minmax(0, 1fr))",
          5: "repeat(5, minmax(0, 1fr))",
          6: "repeat(6, minmax(0, 1fr))",
          7: "repeat(7, minmax(0, 1fr))",
          8: "repeat(8, minmax(0, 1fr))",
          9: "repeat(9, minmax(0, 1fr))",
          10: "repeat(10, minmax(0, 1fr))",
          11: "repeat(11, minmax(0, 1fr))",
          12: "repeat(12, minmax(0, 1fr))"
        },
        gridTemplateRows: {
          none: "none",
          subgrid: "subgrid",
          1: "repeat(1, minmax(0, 1fr))",
          2: "repeat(2, minmax(0, 1fr))",
          3: "repeat(3, minmax(0, 1fr))",
          4: "repeat(4, minmax(0, 1fr))",
          5: "repeat(5, minmax(0, 1fr))",
          6: "repeat(6, minmax(0, 1fr))",
          7: "repeat(7, minmax(0, 1fr))",
          8: "repeat(8, minmax(0, 1fr))",
          9: "repeat(9, minmax(0, 1fr))",
          10: "repeat(10, minmax(0, 1fr))",
          11: "repeat(11, minmax(0, 1fr))",
          12: "repeat(12, minmax(0, 1fr))"
        },
        height: ({ theme }) => ({
          auto: "auto",
          ...theme("spacing"),
          "1/2": "50%",
          "1/3": "33.333333%",
          "2/3": "66.666667%",
          "1/4": "25%",
          "2/4": "50%",
          "3/4": "75%",
          "1/5": "20%",
          "2/5": "40%",
          "3/5": "60%",
          "4/5": "80%",
          "1/6": "16.666667%",
          "2/6": "33.333333%",
          "3/6": "50%",
          "4/6": "66.666667%",
          "5/6": "83.333333%",
          full: "100%",
          screen: "100vh",
          svh: "100svh",
          lvh: "100lvh",
          dvh: "100dvh",
          min: "min-content",
          max: "max-content",
          fit: "fit-content"
        }),
        hueRotate: {
          0: "0deg",
          15: "15deg",
          30: "30deg",
          60: "60deg",
          90: "90deg",
          180: "180deg"
        },
        inset: ({ theme }) => ({
          auto: "auto",
          ...theme("spacing"),
          "1/2": "50%",
          "1/3": "33.333333%",
          "2/3": "66.666667%",
          "1/4": "25%",
          "2/4": "50%",
          "3/4": "75%",
          full: "100%"
        }),
        invert: {
          0: "0",
          DEFAULT: "100%"
        },
        keyframes: {
          spin: {
            to: {
              transform: "rotate(360deg)"
            }
          },
          ping: {
            "75%, 100%": {
              transform: "scale(2)",
              opacity: "0"
            }
          },
          pulse: {
            "50%": {
              opacity: ".5"
            }
          },
          bounce: {
            "0%, 100%": {
              transform: "translateY(-25%)",
              animationTimingFunction: "cubic-bezier(0.8,0,1,1)"
            },
            "50%": {
              transform: "none",
              animationTimingFunction: "cubic-bezier(0,0,0.2,1)"
            }
          }
        },
        letterSpacing: {
          tighter: "-0.05em",
          tight: "-0.025em",
          normal: "0em",
          wide: "0.025em",
          wider: "0.05em",
          widest: "0.1em"
        },
        lineHeight: {
          none: "1",
          tight: "1.25",
          snug: "1.375",
          normal: "1.5",
          relaxed: "1.625",
          loose: "2",
          3: ".75rem",
          4: "1rem",
          5: "1.25rem",
          6: "1.5rem",
          7: "1.75rem",
          8: "2rem",
          9: "2.25rem",
          10: "2.5rem"
        },
        listStyleType: {
          none: "none",
          disc: "disc",
          decimal: "decimal"
        },
        listStyleImage: {
          none: "none"
        },
        margin: ({ theme }) => ({
          auto: "auto",
          ...theme("spacing")
        }),
        lineClamp: {
          1: "1",
          2: "2",
          3: "3",
          4: "4",
          5: "5",
          6: "6"
        },
        maxHeight: ({ theme }) => ({
          ...theme("spacing"),
          none: "none",
          full: "100%",
          screen: "100vh",
          svh: "100svh",
          lvh: "100lvh",
          dvh: "100dvh",
          min: "min-content",
          max: "max-content",
          fit: "fit-content"
        }),
        maxWidth: ({ theme, breakpoints }) => ({
          ...theme("spacing"),
          none: "none",
          xs: "20rem",
          sm: "24rem",
          md: "28rem",
          lg: "32rem",
          xl: "36rem",
          "2xl": "42rem",
          "3xl": "48rem",
          "4xl": "56rem",
          "5xl": "64rem",
          "6xl": "72rem",
          "7xl": "80rem",
          full: "100%",
          min: "min-content",
          max: "max-content",
          fit: "fit-content",
          prose: "65ch",
          ...breakpoints(theme("screens"))
        }),
        minHeight: ({ theme }) => ({
          ...theme("spacing"),
          full: "100%",
          screen: "100vh",
          svh: "100svh",
          lvh: "100lvh",
          dvh: "100dvh",
          min: "min-content",
          max: "max-content",
          fit: "fit-content"
        }),
        minWidth: ({ theme }) => ({
          ...theme("spacing"),
          full: "100%",
          min: "min-content",
          max: "max-content",
          fit: "fit-content"
        }),
        objectPosition: {
          bottom: "bottom",
          center: "center",
          left: "left",
          "left-bottom": "left bottom",
          "left-top": "left top",
          right: "right",
          "right-bottom": "right bottom",
          "right-top": "right top",
          top: "top"
        },
        opacity: {
          0: "0",
          5: "0.05",
          10: "0.1",
          15: "0.15",
          20: "0.2",
          25: "0.25",
          30: "0.3",
          35: "0.35",
          40: "0.4",
          45: "0.45",
          50: "0.5",
          55: "0.55",
          60: "0.6",
          65: "0.65",
          70: "0.7",
          75: "0.75",
          80: "0.8",
          85: "0.85",
          90: "0.9",
          95: "0.95",
          100: "1"
        },
        order: {
          first: "-9999",
          last: "9999",
          none: "0",
          1: "1",
          2: "2",
          3: "3",
          4: "4",
          5: "5",
          6: "6",
          7: "7",
          8: "8",
          9: "9",
          10: "10",
          11: "11",
          12: "12"
        },
        outlineColor: ({ theme }) => theme("colors"),
        outlineOffset: {
          0: "0px",
          1: "1px",
          2: "2px",
          4: "4px",
          8: "8px"
        },
        outlineWidth: {
          0: "0px",
          1: "1px",
          2: "2px",
          4: "4px",
          8: "8px"
        },
        padding: ({ theme }) => theme("spacing"),
        placeholderColor: ({ theme }) => theme("colors"),
        placeholderOpacity: ({ theme }) => theme("opacity"),
        ringColor: ({ theme }) => ({
          DEFAULT: theme("colors.blue.500", "#3b82f6"),
          ...theme("colors")
        }),
        ringOffsetColor: ({ theme }) => theme("colors"),
        ringOffsetWidth: {
          0: "0px",
          1: "1px",
          2: "2px",
          4: "4px",
          8: "8px"
        },
        ringOpacity: ({ theme }) => ({
          DEFAULT: "0.5",
          ...theme("opacity")
        }),
        ringWidth: {
          DEFAULT: "3px",
          0: "0px",
          1: "1px",
          2: "2px",
          4: "4px",
          8: "8px"
        },
        rotate: {
          0: "0deg",
          1: "1deg",
          2: "2deg",
          3: "3deg",
          6: "6deg",
          12: "12deg",
          45: "45deg",
          90: "90deg",
          180: "180deg"
        },
        saturate: {
          0: "0",
          50: ".5",
          100: "1",
          150: "1.5",
          200: "2"
        },
        scale: {
          0: "0",
          50: ".5",
          75: ".75",
          90: ".9",
          95: ".95",
          100: "1",
          105: "1.05",
          110: "1.1",
          125: "1.25",
          150: "1.5"
        },
        screens: {
          sm: "640px",
          md: "768px",
          lg: "1024px",
          xl: "1280px",
          "2xl": "1536px"
        },
        scrollMargin: ({ theme }) => ({
          ...theme("spacing")
        }),
        scrollPadding: ({ theme }) => theme("spacing"),
        sepia: {
          0: "0",
          DEFAULT: "100%"
        },
        skew: {
          0: "0deg",
          1: "1deg",
          2: "2deg",
          3: "3deg",
          6: "6deg",
          12: "12deg"
        },
        space: ({ theme }) => ({
          ...theme("spacing")
        }),
        spacing: {
          px: "1px",
          0: "0px",
          0.5: "0.125rem",
          1: "0.25rem",
          1.5: "0.375rem",
          2: "0.5rem",
          2.5: "0.625rem",
          3: "0.75rem",
          3.5: "0.875rem",
          4: "1rem",
          5: "1.25rem",
          6: "1.5rem",
          7: "1.75rem",
          8: "2rem",
          9: "2.25rem",
          10: "2.5rem",
          11: "2.75rem",
          12: "3rem",
          14: "3.5rem",
          16: "4rem",
          20: "5rem",
          24: "6rem",
          28: "7rem",
          32: "8rem",
          36: "9rem",
          40: "10rem",
          44: "11rem",
          48: "12rem",
          52: "13rem",
          56: "14rem",
          60: "15rem",
          64: "16rem",
          72: "18rem",
          80: "20rem",
          96: "24rem"
        },
        stroke: ({ theme }) => ({
          none: "none",
          ...theme("colors")
        }),
        strokeWidth: {
          0: "0",
          1: "1",
          2: "2"
        },
        supports: {},
        data: {},
        textColor: ({ theme }) => theme("colors"),
        textDecorationColor: ({ theme }) => theme("colors"),
        textDecorationThickness: {
          auto: "auto",
          "from-font": "from-font",
          0: "0px",
          1: "1px",
          2: "2px",
          4: "4px",
          8: "8px"
        },
        textIndent: ({ theme }) => ({
          ...theme("spacing")
        }),
        textOpacity: ({ theme }) => theme("opacity"),
        textUnderlineOffset: {
          auto: "auto",
          0: "0px",
          1: "1px",
          2: "2px",
          4: "4px",
          8: "8px"
        },
        transformOrigin: {
          center: "center",
          top: "top",
          "top-right": "top right",
          right: "right",
          "bottom-right": "bottom right",
          bottom: "bottom",
          "bottom-left": "bottom left",
          left: "left",
          "top-left": "top left"
        },
        transitionDelay: {
          0: "0s",
          75: "75ms",
          100: "100ms",
          150: "150ms",
          200: "200ms",
          300: "300ms",
          500: "500ms",
          700: "700ms",
          1e3: "1000ms"
        },
        transitionDuration: {
          DEFAULT: "150ms",
          0: "0s",
          75: "75ms",
          100: "100ms",
          150: "150ms",
          200: "200ms",
          300: "300ms",
          500: "500ms",
          700: "700ms",
          1e3: "1000ms"
        },
        transitionProperty: {
          none: "none",
          all: "all",
          DEFAULT: "color, background-color, border-color, text-decoration-color, fill, stroke, opacity, box-shadow, transform, filter, backdrop-filter",
          colors: "color, background-color, border-color, text-decoration-color, fill, stroke",
          opacity: "opacity",
          shadow: "box-shadow",
          transform: "transform"
        },
        transitionTimingFunction: {
          DEFAULT: "cubic-bezier(0.4, 0, 0.2, 1)",
          linear: "linear",
          in: "cubic-bezier(0.4, 0, 1, 1)",
          out: "cubic-bezier(0, 0, 0.2, 1)",
          "in-out": "cubic-bezier(0.4, 0, 0.2, 1)"
        },
        translate: ({ theme }) => ({
          ...theme("spacing"),
          "1/2": "50%",
          "1/3": "33.333333%",
          "2/3": "66.666667%",
          "1/4": "25%",
          "2/4": "50%",
          "3/4": "75%",
          full: "100%"
        }),
        size: ({ theme }) => ({
          auto: "auto",
          ...theme("spacing"),
          "1/2": "50%",
          "1/3": "33.333333%",
          "2/3": "66.666667%",
          "1/4": "25%",
          "2/4": "50%",
          "3/4": "75%",
          "1/5": "20%",
          "2/5": "40%",
          "3/5": "60%",
          "4/5": "80%",
          "1/6": "16.666667%",
          "2/6": "33.333333%",
          "3/6": "50%",
          "4/6": "66.666667%",
          "5/6": "83.333333%",
          "1/12": "8.333333%",
          "2/12": "16.666667%",
          "3/12": "25%",
          "4/12": "33.333333%",
          "5/12": "41.666667%",
          "6/12": "50%",
          "7/12": "58.333333%",
          "8/12": "66.666667%",
          "9/12": "75%",
          "10/12": "83.333333%",
          "11/12": "91.666667%",
          full: "100%",
          min: "min-content",
          max: "max-content",
          fit: "fit-content"
        }),
        width: ({ theme }) => ({
          auto: "auto",
          ...theme("spacing"),
          "1/2": "50%",
          "1/3": "33.333333%",
          "2/3": "66.666667%",
          "1/4": "25%",
          "2/4": "50%",
          "3/4": "75%",
          "1/5": "20%",
          "2/5": "40%",
          "3/5": "60%",
          "4/5": "80%",
          "1/6": "16.666667%",
          "2/6": "33.333333%",
          "3/6": "50%",
          "4/6": "66.666667%",
          "5/6": "83.333333%",
          "1/12": "8.333333%",
          "2/12": "16.666667%",
          "3/12": "25%",
          "4/12": "33.333333%",
          "5/12": "41.666667%",
          "6/12": "50%",
          "7/12": "58.333333%",
          "8/12": "66.666667%",
          "9/12": "75%",
          "10/12": "83.333333%",
          "11/12": "91.666667%",
          full: "100%",
          screen: "100vw",
          svw: "100svw",
          lvw: "100lvw",
          dvw: "100dvw",
          min: "min-content",
          max: "max-content",
          fit: "fit-content"
        }),
        willChange: {
          auto: "auto",
          scroll: "scroll-position",
          contents: "contents",
          transform: "transform"
        },
        zIndex: {
          auto: "auto",
          0: "0",
          10: "10",
          20: "20",
          30: "30",
          40: "40",
          50: "50"
        }
      },
      plugins: []
    };
  }
});

// node_modules/tailwindcss/lib/public/default-theme.js
var require_default_theme = __commonJS({
  "node_modules/tailwindcss/lib/public/default-theme.js"(exports) {
    "use strict";
    Object.defineProperty(exports, "__esModule", {
      value: true
    });
    Object.defineProperty(exports, "default", {
      enumerable: true,
      get: function() {
        return _default;
      }
    });
    var _cloneDeep = require_cloneDeep();
    var _configfull = /* @__PURE__ */ _interop_require_default(require_config_full());
    function _interop_require_default(obj) {
      return obj && obj.__esModule ? obj : {
        default: obj
      };
    }
    var _default = (0, _cloneDeep.cloneDeep)(_configfull.default.theme);
  }
});

// node_modules/tailwindcss/defaultTheme.js
var require_defaultTheme = __commonJS({
  "node_modules/tailwindcss/defaultTheme.js"(exports, module) {
    var defaultTheme = require_default_theme();
    module.exports = (defaultTheme.__esModule ? defaultTheme : { default: defaultTheme }).default;
  }
});

// node_modules/picocolors/picocolors.browser.js
var require_picocolors_browser = __commonJS({
  "node_modules/picocolors/picocolors.browser.js"(exports, module) {
    var x = String;
    var create = function() {
      return { isColorSupported: false, reset: x, bold: x, dim: x, italic: x, underline: x, inverse: x, hidden: x, strikethrough: x, black: x, red: x, green: x, yellow: x, blue: x, magenta: x, cyan: x, white: x, gray: x, bgBlack: x, bgRed: x, bgGreen: x, bgYellow: x, bgBlue: x, bgMagenta: x, bgCyan: x, bgWhite: x, blackBright: x, redBright: x, greenBright: x, yellowBright: x, blueBright: x, magentaBright: x, cyanBright: x, whiteBright: x, bgBlackBright: x, bgRedBright: x, bgGreenBright: x, bgYellowBright: x, bgBlueBright: x, bgMagentaBright: x, bgCyanBright: x, bgWhiteBright: x };
    };
    module.exports = create();
    module.exports.createColors = create;
  }
});

// node_modules/tailwindcss/lib/util/log.js
var require_log = __commonJS({
  "node_modules/tailwindcss/lib/util/log.js"(exports) {
    "use strict";
    Object.defineProperty(exports, "__esModule", {
      value: true
    });
    function _export(target, all) {
      for (var name in all) Object.defineProperty(target, name, {
        enumerable: true,
        get: all[name]
      });
    }
    _export(exports, {
      dim: function() {
        return dim;
      },
      default: function() {
        return _default;
      }
    });
    var _picocolors = /* @__PURE__ */ _interop_require_default(require_picocolors_browser());
    function _interop_require_default(obj) {
      return obj && obj.__esModule ? obj : {
        default: obj
      };
    }
    var alreadyShown = /* @__PURE__ */ new Set();
    function log(type, messages, key) {
      if (typeof process !== "undefined" && process.env.JEST_WORKER_ID) return;
      if (key && alreadyShown.has(key)) return;
      if (key) alreadyShown.add(key);
      console.warn("");
      messages.forEach((message) => console.warn(type, "-", message));
    }
    function dim(input) {
      return _picocolors.default.dim(input);
    }
    var _default = {
      info(key, messages) {
        log(_picocolors.default.bold(_picocolors.default.cyan("info")), ...Array.isArray(key) ? [
          key
        ] : [
          messages,
          key
        ]);
      },
      warn(key, messages) {
        log(_picocolors.default.bold(_picocolors.default.yellow("warn")), ...Array.isArray(key) ? [
          key
        ] : [
          messages,
          key
        ]);
      },
      risk(key, messages) {
        log(_picocolors.default.bold(_picocolors.default.magenta("risk")), ...Array.isArray(key) ? [
          key
        ] : [
          messages,
          key
        ]);
      }
    };
  }
});

// node_modules/tailwindcss/lib/public/colors.js
var require_colors = __commonJS({
  "node_modules/tailwindcss/lib/public/colors.js"(exports) {
    "use strict";
    Object.defineProperty(exports, "__esModule", {
      value: true
    });
    Object.defineProperty(exports, "default", {
      enumerable: true,
      get: function() {
        return _default;
      }
    });
    var _log = /* @__PURE__ */ _interop_require_default(require_log());
    function _interop_require_default(obj) {
      return obj && obj.__esModule ? obj : {
        default: obj
      };
    }
    function warn({ version, from, to }) {
      _log.default.warn(`${from}-color-renamed`, [
        `As of Tailwind CSS ${version}, \`${from}\` has been renamed to \`${to}\`.`,
        "Update your configuration file to silence this warning."
      ]);
    }
    var _default = {
      inherit: "inherit",
      current: "currentColor",
      transparent: "transparent",
      black: "#000",
      white: "#fff",
      slate: {
        50: "#f8fafc",
        100: "#f1f5f9",
        200: "#e2e8f0",
        300: "#cbd5e1",
        400: "#94a3b8",
        500: "#64748b",
        600: "#475569",
        700: "#334155",
        800: "#1e293b",
        900: "#0f172a",
        950: "#020617"
      },
      gray: {
        50: "#f9fafb",
        100: "#f3f4f6",
        200: "#e5e7eb",
        300: "#d1d5db",
        400: "#9ca3af",
        500: "#6b7280",
        600: "#4b5563",
        700: "#374151",
        800: "#1f2937",
        900: "#111827",
        950: "#030712"
      },
      zinc: {
        50: "#fafafa",
        100: "#f4f4f5",
        200: "#e4e4e7",
        300: "#d4d4d8",
        400: "#a1a1aa",
        500: "#71717a",
        600: "#52525b",
        700: "#3f3f46",
        800: "#27272a",
        900: "#18181b",
        950: "#09090b"
      },
      neutral: {
        50: "#fafafa",
        100: "#f5f5f5",
        200: "#e5e5e5",
        300: "#d4d4d4",
        400: "#a3a3a3",
        500: "#737373",
        600: "#525252",
        700: "#404040",
        800: "#262626",
        900: "#171717",
        950: "#0a0a0a"
      },
      stone: {
        50: "#fafaf9",
        100: "#f5f5f4",
        200: "#e7e5e4",
        300: "#d6d3d1",
        400: "#a8a29e",
        500: "#78716c",
        600: "#57534e",
        700: "#44403c",
        800: "#292524",
        900: "#1c1917",
        950: "#0c0a09"
      },
      red: {
        50: "#fef2f2",
        100: "#fee2e2",
        200: "#fecaca",
        300: "#fca5a5",
        400: "#f87171",
        500: "#ef4444",
        600: "#dc2626",
        700: "#b91c1c",
        800: "#991b1b",
        900: "#7f1d1d",
        950: "#450a0a"
      },
      orange: {
        50: "#fff7ed",
        100: "#ffedd5",
        200: "#fed7aa",
        300: "#fdba74",
        400: "#fb923c",
        500: "#f97316",
        600: "#ea580c",
        700: "#c2410c",
        800: "#9a3412",
        900: "#7c2d12",
        950: "#431407"
      },
      amber: {
        50: "#fffbeb",
        100: "#fef3c7",
        200: "#fde68a",
        300: "#fcd34d",
        400: "#fbbf24",
        500: "#f59e0b",
        600: "#d97706",
        700: "#b45309",
        800: "#92400e",
        900: "#78350f",
        950: "#451a03"
      },
      yellow: {
        50: "#fefce8",
        100: "#fef9c3",
        200: "#fef08a",
        300: "#fde047",
        400: "#facc15",
        500: "#eab308",
        600: "#ca8a04",
        700: "#a16207",
        800: "#854d0e",
        900: "#713f12",
        950: "#422006"
      },
      lime: {
        50: "#f7fee7",
        100: "#ecfccb",
        200: "#d9f99d",
        300: "#bef264",
        400: "#a3e635",
        500: "#84cc16",
        600: "#65a30d",
        700: "#4d7c0f",
        800: "#3f6212",
        900: "#365314",
        950: "#1a2e05"
      },
      green: {
        50: "#f0fdf4",
        100: "#dcfce7",
        200: "#bbf7d0",
        300: "#86efac",
        400: "#4ade80",
        500: "#22c55e",
        600: "#16a34a",
        700: "#15803d",
        800: "#166534",
        900: "#14532d",
        950: "#052e16"
      },
      emerald: {
        50: "#ecfdf5",
        100: "#d1fae5",
        200: "#a7f3d0",
        300: "#6ee7b7",
        400: "#34d399",
        500: "#10b981",
        600: "#059669",
        700: "#047857",
        800: "#065f46",
        900: "#064e3b",
        950: "#022c22"
      },
      teal: {
        50: "#f0fdfa",
        100: "#ccfbf1",
        200: "#99f6e4",
        300: "#5eead4",
        400: "#2dd4bf",
        500: "#14b8a6",
        600: "#0d9488",
        700: "#0f766e",
        800: "#115e59",
        900: "#134e4a",
        950: "#042f2e"
      },
      cyan: {
        50: "#ecfeff",
        100: "#cffafe",
        200: "#a5f3fc",
        300: "#67e8f9",
        400: "#22d3ee",
        500: "#06b6d4",
        600: "#0891b2",
        700: "#0e7490",
        800: "#155e75",
        900: "#164e63",
        950: "#083344"
      },
      sky: {
        50: "#f0f9ff",
        100: "#e0f2fe",
        200: "#bae6fd",
        300: "#7dd3fc",
        400: "#38bdf8",
        500: "#0ea5e9",
        600: "#0284c7",
        700: "#0369a1",
        800: "#075985",
        900: "#0c4a6e",
        950: "#082f49"
      },
      blue: {
        50: "#eff6ff",
        100: "#dbeafe",
        200: "#bfdbfe",
        300: "#93c5fd",
        400: "#60a5fa",
        500: "#3b82f6",
        600: "#2563eb",
        700: "#1d4ed8",
        800: "#1e40af",
        900: "#1e3a8a",
        950: "#172554"
      },
      indigo: {
        50: "#eef2ff",
        100: "#e0e7ff",
        200: "#c7d2fe",
        300: "#a5b4fc",
        400: "#818cf8",
        500: "#6366f1",
        600: "#4f46e5",
        700: "#4338ca",
        800: "#3730a3",
        900: "#312e81",
        950: "#1e1b4b"
      },
      violet: {
        50: "#f5f3ff",
        100: "#ede9fe",
        200: "#ddd6fe",
        300: "#c4b5fd",
        400: "#a78bfa",
        500: "#8b5cf6",
        600: "#7c3aed",
        700: "#6d28d9",
        800: "#5b21b6",
        900: "#4c1d95",
        950: "#2e1065"
      },
      purple: {
        50: "#faf5ff",
        100: "#f3e8ff",
        200: "#e9d5ff",
        300: "#d8b4fe",
        400: "#c084fc",
        500: "#a855f7",
        600: "#9333ea",
        700: "#7e22ce",
        800: "#6b21a8",
        900: "#581c87",
        950: "#3b0764"
      },
      fuchsia: {
        50: "#fdf4ff",
        100: "#fae8ff",
        200: "#f5d0fe",
        300: "#f0abfc",
        400: "#e879f9",
        500: "#d946ef",
        600: "#c026d3",
        700: "#a21caf",
        800: "#86198f",
        900: "#701a75",
        950: "#4a044e"
      },
      pink: {
        50: "#fdf2f8",
        100: "#fce7f3",
        200: "#fbcfe8",
        300: "#f9a8d4",
        400: "#f472b6",
        500: "#ec4899",
        600: "#db2777",
        700: "#be185d",
        800: "#9d174d",
        900: "#831843",
        950: "#500724"
      },
      rose: {
        50: "#fff1f2",
        100: "#ffe4e6",
        200: "#fecdd3",
        300: "#fda4af",
        400: "#fb7185",
        500: "#f43f5e",
        600: "#e11d48",
        700: "#be123c",
        800: "#9f1239",
        900: "#881337",
        950: "#4c0519"
      },
      get lightBlue() {
        warn({
          version: "v2.2",
          from: "lightBlue",
          to: "sky"
        });
        return this.sky;
      },
      get warmGray() {
        warn({
          version: "v3.0",
          from: "warmGray",
          to: "stone"
        });
        return this.stone;
      },
      get trueGray() {
        warn({
          version: "v3.0",
          from: "trueGray",
          to: "neutral"
        });
        return this.neutral;
      },
      get coolGray() {
        warn({
          version: "v3.0",
          from: "coolGray",
          to: "gray"
        });
        return this.gray;
      },
      get blueGray() {
        warn({
          version: "v3.0",
          from: "blueGray",
          to: "slate"
        });
        return this.slate;
      }
    };
  }
});

// node_modules/tailwindcss/colors.js
var require_colors2 = __commonJS({
  "node_modules/tailwindcss/colors.js"(exports, module) {
    var colors = require_colors();
    module.exports = (colors.__esModule ? colors : { default: colors }).default;
  }
});

// node_modules/@tailwindcss/forms/src/index.js
var require_src = __commonJS({
  "node_modules/@tailwindcss/forms/src/index.js"(exports, module) {
    var svgToDataUri = require_mini_svg_data_uri();
    var plugin2 = require_plugin();
    var defaultTheme = require_defaultTheme();
    var colors = require_colors2();
    var [baseFontSize, { lineHeight: baseLineHeight }] = defaultTheme.fontSize.base;
    var { spacing, borderWidth, borderRadius } = defaultTheme;
    function resolveColor(color, opacityVariableName) {
      return color.replace("<alpha-value>", `var(${opacityVariableName}, 1)`);
    }
    var forms = plugin2.withOptions(function(options = { strategy: void 0 }) {
      return function({ addBase, addComponents, theme }) {
        function resolveChevronColor(color, fallback) {
          let resolved = theme(color);
          if (!resolved || resolved.includes("var(")) {
            return fallback;
          }
          return resolved.replace("<alpha-value>", "1");
        }
        const strategy = options.strategy === void 0 ? ["base", "class"] : [options.strategy];
        const rules = [
          {
            base: [
              "[type='text']",
              "input:where(:not([type]))",
              "[type='email']",
              "[type='url']",
              "[type='password']",
              "[type='number']",
              "[type='date']",
              "[type='datetime-local']",
              "[type='month']",
              "[type='search']",
              "[type='tel']",
              "[type='time']",
              "[type='week']",
              "[multiple]",
              "textarea",
              "select"
            ],
            class: [".form-input", ".form-textarea", ".form-select", ".form-multiselect"],
            styles: {
              appearance: "none",
              "background-color": "#fff",
              "border-color": resolveColor(
                theme("colors.gray.500", colors.gray[500]),
                "--tw-border-opacity"
              ),
              "border-width": borderWidth["DEFAULT"],
              "border-radius": borderRadius.none,
              "padding-top": spacing[2],
              "padding-right": spacing[3],
              "padding-bottom": spacing[2],
              "padding-left": spacing[3],
              "font-size": baseFontSize,
              "line-height": baseLineHeight,
              "--tw-shadow": "0 0 #0000",
              "&:focus": {
                outline: "2px solid transparent",
                "outline-offset": "2px",
                "--tw-ring-inset": "var(--tw-empty,/*!*/ /*!*/)",
                "--tw-ring-offset-width": "0px",
                "--tw-ring-offset-color": "#fff",
                "--tw-ring-color": resolveColor(
                  theme("colors.blue.600", colors.blue[600]),
                  "--tw-ring-opacity"
                ),
                "--tw-ring-offset-shadow": `var(--tw-ring-inset) 0 0 0 var(--tw-ring-offset-width) var(--tw-ring-offset-color)`,
                "--tw-ring-shadow": `var(--tw-ring-inset) 0 0 0 calc(1px + var(--tw-ring-offset-width)) var(--tw-ring-color)`,
                "box-shadow": `var(--tw-ring-offset-shadow), var(--tw-ring-shadow), var(--tw-shadow)`,
                "border-color": resolveColor(
                  theme("colors.blue.600", colors.blue[600]),
                  "--tw-border-opacity"
                )
              }
            }
          },
          {
            base: ["input::placeholder", "textarea::placeholder"],
            class: [".form-input::placeholder", ".form-textarea::placeholder"],
            styles: {
              color: resolveColor(theme("colors.gray.500", colors.gray[500]), "--tw-text-opacity"),
              opacity: "1"
            }
          },
          {
            base: ["::-webkit-datetime-edit-fields-wrapper"],
            class: [".form-input::-webkit-datetime-edit-fields-wrapper"],
            styles: {
              padding: "0"
            }
          },
          {
            // Unfortunate hack until https://bugs.webkit.org/show_bug.cgi?id=198959 is fixed.
            // This sucks because users can't change line-height with a utility on date inputs now.
            // Reference: https://github.com/twbs/bootstrap/pull/31993
            base: ["::-webkit-date-and-time-value"],
            class: [".form-input::-webkit-date-and-time-value"],
            styles: {
              "min-height": "1.5em"
            }
          },
          {
            // In Safari on iOS date and time inputs are centered instead of left-aligned and can't be
            // changed with `text-align` utilities on the input by default. Resetting this to `inherit`
            // makes them left-aligned by default and makes it possible to override the alignment with
            // utility classes without using an arbitrary variant to target the pseudo-elements.
            base: ["::-webkit-date-and-time-value"],
            class: [".form-input::-webkit-date-and-time-value"],
            styles: {
              "text-align": "inherit"
            }
          },
          {
            // In Safari on macOS date time inputs that are set to `display: block` have unexpected
            // extra bottom spacing. This can be corrected by setting the `::-webkit-datetime-edit`
            // pseudo-element to `display: inline-flex`, instead of the browser default of
            // `display: inline-block`.
            base: ["::-webkit-datetime-edit"],
            class: [".form-input::-webkit-datetime-edit"],
            styles: {
              display: "inline-flex"
            }
          },
          {
            // In Safari on macOS date time inputs are 4px taller than normal inputs
            // This is because there is extra padding on the datetime-edit and datetime-edit-{part}-field pseudo elements
            // See https://github.com/tailwindlabs/tailwindcss-forms/issues/95
            base: [
              "::-webkit-datetime-edit",
              "::-webkit-datetime-edit-year-field",
              "::-webkit-datetime-edit-month-field",
              "::-webkit-datetime-edit-day-field",
              "::-webkit-datetime-edit-hour-field",
              "::-webkit-datetime-edit-minute-field",
              "::-webkit-datetime-edit-second-field",
              "::-webkit-datetime-edit-millisecond-field",
              "::-webkit-datetime-edit-meridiem-field"
            ],
            class: [
              ".form-input::-webkit-datetime-edit",
              ".form-input::-webkit-datetime-edit-year-field",
              ".form-input::-webkit-datetime-edit-month-field",
              ".form-input::-webkit-datetime-edit-day-field",
              ".form-input::-webkit-datetime-edit-hour-field",
              ".form-input::-webkit-datetime-edit-minute-field",
              ".form-input::-webkit-datetime-edit-second-field",
              ".form-input::-webkit-datetime-edit-millisecond-field",
              ".form-input::-webkit-datetime-edit-meridiem-field"
            ],
            styles: {
              "padding-top": 0,
              "padding-bottom": 0
            }
          },
          {
            base: ["select"],
            class: [".form-select"],
            styles: {
              "background-image": `url("${svgToDataUri(
                `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 20 20"><path stroke="${resolveChevronColor(
                  "colors.gray.500",
                  colors.gray[500]
                )}" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M6 8l4 4 4-4"/></svg>`
              )}")`,
              "background-position": `right ${spacing[2]} center`,
              "background-repeat": `no-repeat`,
              "background-size": `1.5em 1.5em`,
              "padding-right": spacing[10],
              "print-color-adjust": `exact`
            }
          },
          {
            base: ["[multiple]", '[size]:where(select:not([size="1"]))'],
            class: ['.form-select:where([size]:not([size="1"]))'],
            styles: {
              "background-image": "initial",
              "background-position": "initial",
              "background-repeat": "unset",
              "background-size": "initial",
              "padding-right": spacing[3],
              "print-color-adjust": "unset"
            }
          },
          {
            base: [`[type='checkbox']`, `[type='radio']`],
            class: [".form-checkbox", ".form-radio"],
            styles: {
              appearance: "none",
              padding: "0",
              "print-color-adjust": "exact",
              display: "inline-block",
              "vertical-align": "middle",
              "background-origin": "border-box",
              "user-select": "none",
              "flex-shrink": "0",
              height: spacing[4],
              width: spacing[4],
              color: resolveColor(theme("colors.blue.600", colors.blue[600]), "--tw-text-opacity"),
              "background-color": "#fff",
              "border-color": resolveColor(
                theme("colors.gray.500", colors.gray[500]),
                "--tw-border-opacity"
              ),
              "border-width": borderWidth["DEFAULT"],
              "--tw-shadow": "0 0 #0000"
            }
          },
          {
            base: [`[type='checkbox']`],
            class: [".form-checkbox"],
            styles: {
              "border-radius": borderRadius["none"]
            }
          },
          {
            base: [`[type='radio']`],
            class: [".form-radio"],
            styles: {
              "border-radius": "100%"
            }
          },
          {
            base: [`[type='checkbox']:focus`, `[type='radio']:focus`],
            class: [".form-checkbox:focus", ".form-radio:focus"],
            styles: {
              outline: "2px solid transparent",
              "outline-offset": "2px",
              "--tw-ring-inset": "var(--tw-empty,/*!*/ /*!*/)",
              "--tw-ring-offset-width": "2px",
              "--tw-ring-offset-color": "#fff",
              "--tw-ring-color": resolveColor(
                theme("colors.blue.600", colors.blue[600]),
                "--tw-ring-opacity"
              ),
              "--tw-ring-offset-shadow": `var(--tw-ring-inset) 0 0 0 var(--tw-ring-offset-width) var(--tw-ring-offset-color)`,
              "--tw-ring-shadow": `var(--tw-ring-inset) 0 0 0 calc(2px + var(--tw-ring-offset-width)) var(--tw-ring-color)`,
              "box-shadow": `var(--tw-ring-offset-shadow), var(--tw-ring-shadow), var(--tw-shadow)`
            }
          },
          {
            base: [`[type='checkbox']:checked`, `[type='radio']:checked`],
            class: [".form-checkbox:checked", ".form-radio:checked"],
            styles: {
              "border-color": `transparent`,
              "background-color": `currentColor`,
              "background-size": `100% 100%`,
              "background-position": `center`,
              "background-repeat": `no-repeat`
            }
          },
          {
            base: [`[type='checkbox']:checked`],
            class: [".form-checkbox:checked"],
            styles: {
              "background-image": `url("${svgToDataUri(
                `<svg viewBox="0 0 16 16" fill="white" xmlns="http://www.w3.org/2000/svg"><path d="M12.207 4.793a1 1 0 010 1.414l-5 5a1 1 0 01-1.414 0l-2-2a1 1 0 011.414-1.414L6.5 9.086l4.293-4.293a1 1 0 011.414 0z"/></svg>`
              )}")`,
              "@media (forced-colors: active) ": {
                appearance: "auto"
              }
            }
          },
          {
            base: [`[type='radio']:checked`],
            class: [".form-radio:checked"],
            styles: {
              "background-image": `url("${svgToDataUri(
                `<svg viewBox="0 0 16 16" fill="white" xmlns="http://www.w3.org/2000/svg"><circle cx="8" cy="8" r="3"/></svg>`
              )}")`,
              "@media (forced-colors: active) ": {
                appearance: "auto"
              }
            }
          },
          {
            base: [
              `[type='checkbox']:checked:hover`,
              `[type='checkbox']:checked:focus`,
              `[type='radio']:checked:hover`,
              `[type='radio']:checked:focus`
            ],
            class: [
              ".form-checkbox:checked:hover",
              ".form-checkbox:checked:focus",
              ".form-radio:checked:hover",
              ".form-radio:checked:focus"
            ],
            styles: {
              "border-color": "transparent",
              "background-color": "currentColor"
            }
          },
          {
            base: [`[type='checkbox']:indeterminate`],
            class: [".form-checkbox:indeterminate"],
            styles: {
              "background-image": `url("${svgToDataUri(
                `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 16 16"><path stroke="white" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8h8"/></svg>`
              )}")`,
              "border-color": `transparent`,
              "background-color": `currentColor`,
              "background-size": `100% 100%`,
              "background-position": `center`,
              "background-repeat": `no-repeat`,
              "@media (forced-colors: active) ": {
                appearance: "auto"
              }
            }
          },
          {
            base: [`[type='checkbox']:indeterminate:hover`, `[type='checkbox']:indeterminate:focus`],
            class: [".form-checkbox:indeterminate:hover", ".form-checkbox:indeterminate:focus"],
            styles: {
              "border-color": "transparent",
              "background-color": "currentColor"
            }
          },
          {
            base: [`[type='file']`],
            class: null,
            styles: {
              background: "unset",
              "border-color": "inherit",
              "border-width": "0",
              "border-radius": "0",
              padding: "0",
              "font-size": "unset",
              "line-height": "inherit"
            }
          },
          {
            base: [`[type='file']:focus`],
            class: null,
            styles: {
              outline: [`1px solid ButtonText`, `1px auto -webkit-focus-ring-color`]
            }
          }
        ];
        const getStrategyRules = (strategy2) => rules.map((rule) => {
          if (rule[strategy2] === null) return null;
          return { [rule[strategy2]]: rule.styles };
        }).filter(Boolean);
        if (strategy.includes("base")) {
          addBase(getStrategyRules("base"));
        }
        if (strategy.includes("class")) {
          addComponents(getStrategyRules("class"));
        }
      };
    });
    module.exports = forms;
  }
});

// node_modules/lodash.merge/index.js
var require_lodash = __commonJS({
  "node_modules/lodash.merge/index.js"(exports, module) {
    var LARGE_ARRAY_SIZE = 200;
    var HASH_UNDEFINED = "__lodash_hash_undefined__";
    var HOT_COUNT = 800;
    var HOT_SPAN = 16;
    var MAX_SAFE_INTEGER = 9007199254740991;
    var argsTag = "[object Arguments]";
    var arrayTag = "[object Array]";
    var asyncTag = "[object AsyncFunction]";
    var boolTag = "[object Boolean]";
    var dateTag = "[object Date]";
    var errorTag = "[object Error]";
    var funcTag = "[object Function]";
    var genTag = "[object GeneratorFunction]";
    var mapTag = "[object Map]";
    var numberTag = "[object Number]";
    var nullTag = "[object Null]";
    var objectTag = "[object Object]";
    var proxyTag = "[object Proxy]";
    var regexpTag = "[object RegExp]";
    var setTag = "[object Set]";
    var stringTag = "[object String]";
    var undefinedTag = "[object Undefined]";
    var weakMapTag = "[object WeakMap]";
    var arrayBufferTag = "[object ArrayBuffer]";
    var dataViewTag = "[object DataView]";
    var float32Tag = "[object Float32Array]";
    var float64Tag = "[object Float64Array]";
    var int8Tag = "[object Int8Array]";
    var int16Tag = "[object Int16Array]";
    var int32Tag = "[object Int32Array]";
    var uint8Tag = "[object Uint8Array]";
    var uint8ClampedTag = "[object Uint8ClampedArray]";
    var uint16Tag = "[object Uint16Array]";
    var uint32Tag = "[object Uint32Array]";
    var reRegExpChar = /[\\^$.*+?()[\]{}|]/g;
    var reIsHostCtor = /^\[object .+?Constructor\]$/;
    var reIsUint = /^(?:0|[1-9]\d*)$/;
    var typedArrayTags = {};
    typedArrayTags[float32Tag] = typedArrayTags[float64Tag] = typedArrayTags[int8Tag] = typedArrayTags[int16Tag] = typedArrayTags[int32Tag] = typedArrayTags[uint8Tag] = typedArrayTags[uint8ClampedTag] = typedArrayTags[uint16Tag] = typedArrayTags[uint32Tag] = true;
    typedArrayTags[argsTag] = typedArrayTags[arrayTag] = typedArrayTags[arrayBufferTag] = typedArrayTags[boolTag] = typedArrayTags[dataViewTag] = typedArrayTags[dateTag] = typedArrayTags[errorTag] = typedArrayTags[funcTag] = typedArrayTags[mapTag] = typedArrayTags[numberTag] = typedArrayTags[objectTag] = typedArrayTags[regexpTag] = typedArrayTags[setTag] = typedArrayTags[stringTag] = typedArrayTags[weakMapTag] = false;
    var freeGlobal = typeof global == "object" && global && global.Object === Object && global;
    var freeSelf = typeof self == "object" && self && self.Object === Object && self;
    var root = freeGlobal || freeSelf || Function("return this")();
    var freeExports = typeof exports == "object" && exports && !exports.nodeType && exports;
    var freeModule = freeExports && typeof module == "object" && module && !module.nodeType && module;
    var moduleExports = freeModule && freeModule.exports === freeExports;
    var freeProcess = moduleExports && freeGlobal.process;
    var nodeUtil = function() {
      try {
        var types = freeModule && freeModule.require && freeModule.require("util").types;
        if (types) {
          return types;
        }
        return freeProcess && freeProcess.binding && freeProcess.binding("util");
      } catch (e) {
      }
    }();
    var nodeIsTypedArray = nodeUtil && nodeUtil.isTypedArray;
    function apply(func, thisArg, args) {
      switch (args.length) {
        case 0:
          return func.call(thisArg);
        case 1:
          return func.call(thisArg, args[0]);
        case 2:
          return func.call(thisArg, args[0], args[1]);
        case 3:
          return func.call(thisArg, args[0], args[1], args[2]);
      }
      return func.apply(thisArg, args);
    }
    function baseTimes(n, iteratee) {
      var index = -1, result = Array(n);
      while (++index < n) {
        result[index] = iteratee(index);
      }
      return result;
    }
    function baseUnary(func) {
      return function(value) {
        return func(value);
      };
    }
    function getValue(object, key) {
      return object == null ? void 0 : object[key];
    }
    function overArg(func, transform) {
      return function(arg) {
        return func(transform(arg));
      };
    }
    var arrayProto = Array.prototype;
    var funcProto = Function.prototype;
    var objectProto = Object.prototype;
    var coreJsData = root["__core-js_shared__"];
    var funcToString = funcProto.toString;
    var hasOwnProperty = objectProto.hasOwnProperty;
    var maskSrcKey = function() {
      var uid = /[^.]+$/.exec(coreJsData && coreJsData.keys && coreJsData.keys.IE_PROTO || "");
      return uid ? "Symbol(src)_1." + uid : "";
    }();
    var nativeObjectToString = objectProto.toString;
    var objectCtorString = funcToString.call(Object);
    var reIsNative = RegExp(
      "^" + funcToString.call(hasOwnProperty).replace(reRegExpChar, "\\$&").replace(/hasOwnProperty|(function).*?(?=\\\()| for .+?(?=\\\])/g, "$1.*?") + "$"
    );
    var Buffer2 = moduleExports ? root.Buffer : void 0;
    var Symbol2 = root.Symbol;
    var Uint8Array2 = root.Uint8Array;
    var allocUnsafe = Buffer2 ? Buffer2.allocUnsafe : void 0;
    var getPrototype = overArg(Object.getPrototypeOf, Object);
    var objectCreate = Object.create;
    var propertyIsEnumerable = objectProto.propertyIsEnumerable;
    var splice = arrayProto.splice;
    var symToStringTag = Symbol2 ? Symbol2.toStringTag : void 0;
    var defineProperty = function() {
      try {
        var func = getNative(Object, "defineProperty");
        func({}, "", {});
        return func;
      } catch (e) {
      }
    }();
    var nativeIsBuffer = Buffer2 ? Buffer2.isBuffer : void 0;
    var nativeMax = Math.max;
    var nativeNow = Date.now;
    var Map = getNative(root, "Map");
    var nativeCreate = getNative(Object, "create");
    var baseCreate = /* @__PURE__ */ function() {
      function object() {
      }
      return function(proto) {
        if (!isObject(proto)) {
          return {};
        }
        if (objectCreate) {
          return objectCreate(proto);
        }
        object.prototype = proto;
        var result = new object();
        object.prototype = void 0;
        return result;
      };
    }();
    function Hash(entries) {
      var index = -1, length = entries == null ? 0 : entries.length;
      this.clear();
      while (++index < length) {
        var entry = entries[index];
        this.set(entry[0], entry[1]);
      }
    }
    function hashClear() {
      this.__data__ = nativeCreate ? nativeCreate(null) : {};
      this.size = 0;
    }
    function hashDelete(key) {
      var result = this.has(key) && delete this.__data__[key];
      this.size -= result ? 1 : 0;
      return result;
    }
    function hashGet(key) {
      var data = this.__data__;
      if (nativeCreate) {
        var result = data[key];
        return result === HASH_UNDEFINED ? void 0 : result;
      }
      return hasOwnProperty.call(data, key) ? data[key] : void 0;
    }
    function hashHas(key) {
      var data = this.__data__;
      return nativeCreate ? data[key] !== void 0 : hasOwnProperty.call(data, key);
    }
    function hashSet(key, value) {
      var data = this.__data__;
      this.size += this.has(key) ? 0 : 1;
      data[key] = nativeCreate && value === void 0 ? HASH_UNDEFINED : value;
      return this;
    }
    Hash.prototype.clear = hashClear;
    Hash.prototype["delete"] = hashDelete;
    Hash.prototype.get = hashGet;
    Hash.prototype.has = hashHas;
    Hash.prototype.set = hashSet;
    function ListCache(entries) {
      var index = -1, length = entries == null ? 0 : entries.length;
      this.clear();
      while (++index < length) {
        var entry = entries[index];
        this.set(entry[0], entry[1]);
      }
    }
    function listCacheClear() {
      this.__data__ = [];
      this.size = 0;
    }
    function listCacheDelete(key) {
      var data = this.__data__, index = assocIndexOf(data, key);
      if (index < 0) {
        return false;
      }
      var lastIndex = data.length - 1;
      if (index == lastIndex) {
        data.pop();
      } else {
        splice.call(data, index, 1);
      }
      --this.size;
      return true;
    }
    function listCacheGet(key) {
      var data = this.__data__, index = assocIndexOf(data, key);
      return index < 0 ? void 0 : data[index][1];
    }
    function listCacheHas(key) {
      return assocIndexOf(this.__data__, key) > -1;
    }
    function listCacheSet(key, value) {
      var data = this.__data__, index = assocIndexOf(data, key);
      if (index < 0) {
        ++this.size;
        data.push([key, value]);
      } else {
        data[index][1] = value;
      }
      return this;
    }
    ListCache.prototype.clear = listCacheClear;
    ListCache.prototype["delete"] = listCacheDelete;
    ListCache.prototype.get = listCacheGet;
    ListCache.prototype.has = listCacheHas;
    ListCache.prototype.set = listCacheSet;
    function MapCache(entries) {
      var index = -1, length = entries == null ? 0 : entries.length;
      this.clear();
      while (++index < length) {
        var entry = entries[index];
        this.set(entry[0], entry[1]);
      }
    }
    function mapCacheClear() {
      this.size = 0;
      this.__data__ = {
        "hash": new Hash(),
        "map": new (Map || ListCache)(),
        "string": new Hash()
      };
    }
    function mapCacheDelete(key) {
      var result = getMapData(this, key)["delete"](key);
      this.size -= result ? 1 : 0;
      return result;
    }
    function mapCacheGet(key) {
      return getMapData(this, key).get(key);
    }
    function mapCacheHas(key) {
      return getMapData(this, key).has(key);
    }
    function mapCacheSet(key, value) {
      var data = getMapData(this, key), size = data.size;
      data.set(key, value);
      this.size += data.size == size ? 0 : 1;
      return this;
    }
    MapCache.prototype.clear = mapCacheClear;
    MapCache.prototype["delete"] = mapCacheDelete;
    MapCache.prototype.get = mapCacheGet;
    MapCache.prototype.has = mapCacheHas;
    MapCache.prototype.set = mapCacheSet;
    function Stack(entries) {
      var data = this.__data__ = new ListCache(entries);
      this.size = data.size;
    }
    function stackClear() {
      this.__data__ = new ListCache();
      this.size = 0;
    }
    function stackDelete(key) {
      var data = this.__data__, result = data["delete"](key);
      this.size = data.size;
      return result;
    }
    function stackGet(key) {
      return this.__data__.get(key);
    }
    function stackHas(key) {
      return this.__data__.has(key);
    }
    function stackSet(key, value) {
      var data = this.__data__;
      if (data instanceof ListCache) {
        var pairs = data.__data__;
        if (!Map || pairs.length < LARGE_ARRAY_SIZE - 1) {
          pairs.push([key, value]);
          this.size = ++data.size;
          return this;
        }
        data = this.__data__ = new MapCache(pairs);
      }
      data.set(key, value);
      this.size = data.size;
      return this;
    }
    Stack.prototype.clear = stackClear;
    Stack.prototype["delete"] = stackDelete;
    Stack.prototype.get = stackGet;
    Stack.prototype.has = stackHas;
    Stack.prototype.set = stackSet;
    function arrayLikeKeys(value, inherited) {
      var isArr = isArray(value), isArg = !isArr && isArguments(value), isBuff = !isArr && !isArg && isBuffer(value), isType = !isArr && !isArg && !isBuff && isTypedArray(value), skipIndexes = isArr || isArg || isBuff || isType, result = skipIndexes ? baseTimes(value.length, String) : [], length = result.length;
      for (var key in value) {
        if ((inherited || hasOwnProperty.call(value, key)) && !(skipIndexes && // Safari 9 has enumerable `arguments.length` in strict mode.
        (key == "length" || // Node.js 0.10 has enumerable non-index properties on buffers.
        isBuff && (key == "offset" || key == "parent") || // PhantomJS 2 has enumerable non-index properties on typed arrays.
        isType && (key == "buffer" || key == "byteLength" || key == "byteOffset") || // Skip index properties.
        isIndex(key, length)))) {
          result.push(key);
        }
      }
      return result;
    }
    function assignMergeValue(object, key, value) {
      if (value !== void 0 && !eq(object[key], value) || value === void 0 && !(key in object)) {
        baseAssignValue(object, key, value);
      }
    }
    function assignValue(object, key, value) {
      var objValue = object[key];
      if (!(hasOwnProperty.call(object, key) && eq(objValue, value)) || value === void 0 && !(key in object)) {
        baseAssignValue(object, key, value);
      }
    }
    function assocIndexOf(array, key) {
      var length = array.length;
      while (length--) {
        if (eq(array[length][0], key)) {
          return length;
        }
      }
      return -1;
    }
    function baseAssignValue(object, key, value) {
      if (key == "__proto__" && defineProperty) {
        defineProperty(object, key, {
          "configurable": true,
          "enumerable": true,
          "value": value,
          "writable": true
        });
      } else {
        object[key] = value;
      }
    }
    var baseFor = createBaseFor();
    function baseGetTag(value) {
      if (value == null) {
        return value === void 0 ? undefinedTag : nullTag;
      }
      return symToStringTag && symToStringTag in Object(value) ? getRawTag(value) : objectToString(value);
    }
    function baseIsArguments(value) {
      return isObjectLike(value) && baseGetTag(value) == argsTag;
    }
    function baseIsNative(value) {
      if (!isObject(value) || isMasked(value)) {
        return false;
      }
      var pattern = isFunction(value) ? reIsNative : reIsHostCtor;
      return pattern.test(toSource(value));
    }
    function baseIsTypedArray(value) {
      return isObjectLike(value) && isLength(value.length) && !!typedArrayTags[baseGetTag(value)];
    }
    function baseKeysIn(object) {
      if (!isObject(object)) {
        return nativeKeysIn(object);
      }
      var isProto = isPrototype(object), result = [];
      for (var key in object) {
        if (!(key == "constructor" && (isProto || !hasOwnProperty.call(object, key)))) {
          result.push(key);
        }
      }
      return result;
    }
    function baseMerge(object, source, srcIndex, customizer, stack) {
      if (object === source) {
        return;
      }
      baseFor(source, function(srcValue, key) {
        stack || (stack = new Stack());
        if (isObject(srcValue)) {
          baseMergeDeep(object, source, key, srcIndex, baseMerge, customizer, stack);
        } else {
          var newValue = customizer ? customizer(safeGet(object, key), srcValue, key + "", object, source, stack) : void 0;
          if (newValue === void 0) {
            newValue = srcValue;
          }
          assignMergeValue(object, key, newValue);
        }
      }, keysIn);
    }
    function baseMergeDeep(object, source, key, srcIndex, mergeFunc, customizer, stack) {
      var objValue = safeGet(object, key), srcValue = safeGet(source, key), stacked = stack.get(srcValue);
      if (stacked) {
        assignMergeValue(object, key, stacked);
        return;
      }
      var newValue = customizer ? customizer(objValue, srcValue, key + "", object, source, stack) : void 0;
      var isCommon = newValue === void 0;
      if (isCommon) {
        var isArr = isArray(srcValue), isBuff = !isArr && isBuffer(srcValue), isTyped = !isArr && !isBuff && isTypedArray(srcValue);
        newValue = srcValue;
        if (isArr || isBuff || isTyped) {
          if (isArray(objValue)) {
            newValue = objValue;
          } else if (isArrayLikeObject(objValue)) {
            newValue = copyArray(objValue);
          } else if (isBuff) {
            isCommon = false;
            newValue = cloneBuffer(srcValue, true);
          } else if (isTyped) {
            isCommon = false;
            newValue = cloneTypedArray(srcValue, true);
          } else {
            newValue = [];
          }
        } else if (isPlainObject(srcValue) || isArguments(srcValue)) {
          newValue = objValue;
          if (isArguments(objValue)) {
            newValue = toPlainObject(objValue);
          } else if (!isObject(objValue) || isFunction(objValue)) {
            newValue = initCloneObject(srcValue);
          }
        } else {
          isCommon = false;
        }
      }
      if (isCommon) {
        stack.set(srcValue, newValue);
        mergeFunc(newValue, srcValue, srcIndex, customizer, stack);
        stack["delete"](srcValue);
      }
      assignMergeValue(object, key, newValue);
    }
    function baseRest(func, start) {
      return setToString(overRest(func, start, identity), func + "");
    }
    var baseSetToString = !defineProperty ? identity : function(func, string) {
      return defineProperty(func, "toString", {
        "configurable": true,
        "enumerable": false,
        "value": constant(string),
        "writable": true
      });
    };
    function cloneBuffer(buffer, isDeep) {
      if (isDeep) {
        return buffer.slice();
      }
      var length = buffer.length, result = allocUnsafe ? allocUnsafe(length) : new buffer.constructor(length);
      buffer.copy(result);
      return result;
    }
    function cloneArrayBuffer(arrayBuffer) {
      var result = new arrayBuffer.constructor(arrayBuffer.byteLength);
      new Uint8Array2(result).set(new Uint8Array2(arrayBuffer));
      return result;
    }
    function cloneTypedArray(typedArray, isDeep) {
      var buffer = isDeep ? cloneArrayBuffer(typedArray.buffer) : typedArray.buffer;
      return new typedArray.constructor(buffer, typedArray.byteOffset, typedArray.length);
    }
    function copyArray(source, array) {
      var index = -1, length = source.length;
      array || (array = Array(length));
      while (++index < length) {
        array[index] = source[index];
      }
      return array;
    }
    function copyObject(source, props, object, customizer) {
      var isNew = !object;
      object || (object = {});
      var index = -1, length = props.length;
      while (++index < length) {
        var key = props[index];
        var newValue = customizer ? customizer(object[key], source[key], key, object, source) : void 0;
        if (newValue === void 0) {
          newValue = source[key];
        }
        if (isNew) {
          baseAssignValue(object, key, newValue);
        } else {
          assignValue(object, key, newValue);
        }
      }
      return object;
    }
    function createAssigner(assigner) {
      return baseRest(function(object, sources) {
        var index = -1, length = sources.length, customizer = length > 1 ? sources[length - 1] : void 0, guard = length > 2 ? sources[2] : void 0;
        customizer = assigner.length > 3 && typeof customizer == "function" ? (length--, customizer) : void 0;
        if (guard && isIterateeCall(sources[0], sources[1], guard)) {
          customizer = length < 3 ? void 0 : customizer;
          length = 1;
        }
        object = Object(object);
        while (++index < length) {
          var source = sources[index];
          if (source) {
            assigner(object, source, index, customizer);
          }
        }
        return object;
      });
    }
    function createBaseFor(fromRight) {
      return function(object, iteratee, keysFunc) {
        var index = -1, iterable = Object(object), props = keysFunc(object), length = props.length;
        while (length--) {
          var key = props[fromRight ? length : ++index];
          if (iteratee(iterable[key], key, iterable) === false) {
            break;
          }
        }
        return object;
      };
    }
    function getMapData(map, key) {
      var data = map.__data__;
      return isKeyable(key) ? data[typeof key == "string" ? "string" : "hash"] : data.map;
    }
    function getNative(object, key) {
      var value = getValue(object, key);
      return baseIsNative(value) ? value : void 0;
    }
    function getRawTag(value) {
      var isOwn = hasOwnProperty.call(value, symToStringTag), tag = value[symToStringTag];
      try {
        value[symToStringTag] = void 0;
        var unmasked = true;
      } catch (e) {
      }
      var result = nativeObjectToString.call(value);
      if (unmasked) {
        if (isOwn) {
          value[symToStringTag] = tag;
        } else {
          delete value[symToStringTag];
        }
      }
      return result;
    }
    function initCloneObject(object) {
      return typeof object.constructor == "function" && !isPrototype(object) ? baseCreate(getPrototype(object)) : {};
    }
    function isIndex(value, length) {
      var type = typeof value;
      length = length == null ? MAX_SAFE_INTEGER : length;
      return !!length && (type == "number" || type != "symbol" && reIsUint.test(value)) && (value > -1 && value % 1 == 0 && value < length);
    }
    function isIterateeCall(value, index, object) {
      if (!isObject(object)) {
        return false;
      }
      var type = typeof index;
      if (type == "number" ? isArrayLike(object) && isIndex(index, object.length) : type == "string" && index in object) {
        return eq(object[index], value);
      }
      return false;
    }
    function isKeyable(value) {
      var type = typeof value;
      return type == "string" || type == "number" || type == "symbol" || type == "boolean" ? value !== "__proto__" : value === null;
    }
    function isMasked(func) {
      return !!maskSrcKey && maskSrcKey in func;
    }
    function isPrototype(value) {
      var Ctor = value && value.constructor, proto = typeof Ctor == "function" && Ctor.prototype || objectProto;
      return value === proto;
    }
    function nativeKeysIn(object) {
      var result = [];
      if (object != null) {
        for (var key in Object(object)) {
          result.push(key);
        }
      }
      return result;
    }
    function objectToString(value) {
      return nativeObjectToString.call(value);
    }
    function overRest(func, start, transform) {
      start = nativeMax(start === void 0 ? func.length - 1 : start, 0);
      return function() {
        var args = arguments, index = -1, length = nativeMax(args.length - start, 0), array = Array(length);
        while (++index < length) {
          array[index] = args[start + index];
        }
        index = -1;
        var otherArgs = Array(start + 1);
        while (++index < start) {
          otherArgs[index] = args[index];
        }
        otherArgs[start] = transform(array);
        return apply(func, this, otherArgs);
      };
    }
    function safeGet(object, key) {
      if (key === "constructor" && typeof object[key] === "function") {
        return;
      }
      if (key == "__proto__") {
        return;
      }
      return object[key];
    }
    var setToString = shortOut(baseSetToString);
    function shortOut(func) {
      var count = 0, lastCalled = 0;
      return function() {
        var stamp = nativeNow(), remaining = HOT_SPAN - (stamp - lastCalled);
        lastCalled = stamp;
        if (remaining > 0) {
          if (++count >= HOT_COUNT) {
            return arguments[0];
          }
        } else {
          count = 0;
        }
        return func.apply(void 0, arguments);
      };
    }
    function toSource(func) {
      if (func != null) {
        try {
          return funcToString.call(func);
        } catch (e) {
        }
        try {
          return func + "";
        } catch (e) {
        }
      }
      return "";
    }
    function eq(value, other) {
      return value === other || value !== value && other !== other;
    }
    var isArguments = baseIsArguments(/* @__PURE__ */ function() {
      return arguments;
    }()) ? baseIsArguments : function(value) {
      return isObjectLike(value) && hasOwnProperty.call(value, "callee") && !propertyIsEnumerable.call(value, "callee");
    };
    var isArray = Array.isArray;
    function isArrayLike(value) {
      return value != null && isLength(value.length) && !isFunction(value);
    }
    function isArrayLikeObject(value) {
      return isObjectLike(value) && isArrayLike(value);
    }
    var isBuffer = nativeIsBuffer || stubFalse;
    function isFunction(value) {
      if (!isObject(value)) {
        return false;
      }
      var tag = baseGetTag(value);
      return tag == funcTag || tag == genTag || tag == asyncTag || tag == proxyTag;
    }
    function isLength(value) {
      return typeof value == "number" && value > -1 && value % 1 == 0 && value <= MAX_SAFE_INTEGER;
    }
    function isObject(value) {
      var type = typeof value;
      return value != null && (type == "object" || type == "function");
    }
    function isObjectLike(value) {
      return value != null && typeof value == "object";
    }
    function isPlainObject(value) {
      if (!isObjectLike(value) || baseGetTag(value) != objectTag) {
        return false;
      }
      var proto = getPrototype(value);
      if (proto === null) {
        return true;
      }
      var Ctor = hasOwnProperty.call(proto, "constructor") && proto.constructor;
      return typeof Ctor == "function" && Ctor instanceof Ctor && funcToString.call(Ctor) == objectCtorString;
    }
    var isTypedArray = nodeIsTypedArray ? baseUnary(nodeIsTypedArray) : baseIsTypedArray;
    function toPlainObject(value) {
      return copyObject(value, keysIn(value));
    }
    function keysIn(object) {
      return isArrayLike(object) ? arrayLikeKeys(object, true) : baseKeysIn(object);
    }
    var merge = createAssigner(function(object, source, srcIndex) {
      baseMerge(object, source, srcIndex);
    });
    function constant(value) {
      return function() {
        return value;
      };
    }
    function identity(value) {
      return value;
    }
    function stubFalse() {
      return false;
    }
    module.exports = merge;
  }
});

// node_modules/lodash.castarray/index.js
var require_lodash2 = __commonJS({
  "node_modules/lodash.castarray/index.js"(exports, module) {
    function castArray() {
      if (!arguments.length) {
        return [];
      }
      var value = arguments[0];
      return isArray(value) ? value : [value];
    }
    var isArray = Array.isArray;
    module.exports = castArray;
  }
});

// node_modules/@tailwindcss/typography/src/styles.js
var require_styles = __commonJS({
  "node_modules/@tailwindcss/typography/src/styles.js"(exports, module) {
    var colors = require_colors2();
    var round = (num) => num.toFixed(7).replace(/(\.[0-9]+?)0+$/, "$1").replace(/\.0$/, "");
    var rem = (px) => `${round(px / 16)}rem`;
    var em = (px, base) => `${round(px / base)}em`;
    var hexToRgb = (hex) => {
      hex = hex.replace("#", "");
      hex = hex.length === 3 ? hex.replace(/./g, "$&$&") : hex;
      const r = parseInt(hex.substring(0, 2), 16);
      const g = parseInt(hex.substring(2, 4), 16);
      const b = parseInt(hex.substring(4, 6), 16);
      return `${r} ${g} ${b}`;
    };
    var defaultModifiers = {
      sm: {
        css: [
          {
            fontSize: rem(14),
            lineHeight: round(24 / 14),
            p: {
              marginTop: em(16, 14),
              marginBottom: em(16, 14)
            },
            '[class~="lead"]': {
              fontSize: em(18, 14),
              lineHeight: round(28 / 18),
              marginTop: em(16, 18),
              marginBottom: em(16, 18)
            },
            blockquote: {
              marginTop: em(24, 18),
              marginBottom: em(24, 18),
              paddingInlineStart: em(20, 18)
            },
            h1: {
              fontSize: em(30, 14),
              marginTop: "0",
              marginBottom: em(24, 30),
              lineHeight: round(36 / 30)
            },
            h2: {
              fontSize: em(20, 14),
              marginTop: em(32, 20),
              marginBottom: em(16, 20),
              lineHeight: round(28 / 20)
            },
            h3: {
              fontSize: em(18, 14),
              marginTop: em(28, 18),
              marginBottom: em(8, 18),
              lineHeight: round(28 / 18)
            },
            h4: {
              marginTop: em(20, 14),
              marginBottom: em(8, 14),
              lineHeight: round(20 / 14)
            },
            img: {
              marginTop: em(24, 14),
              marginBottom: em(24, 14)
            },
            picture: {
              marginTop: em(24, 14),
              marginBottom: em(24, 14)
            },
            "picture > img": {
              marginTop: "0",
              marginBottom: "0"
            },
            video: {
              marginTop: em(24, 14),
              marginBottom: em(24, 14)
            },
            kbd: {
              fontSize: em(12, 14),
              borderRadius: rem(5),
              paddingTop: em(2, 14),
              paddingInlineEnd: em(5, 14),
              paddingBottom: em(2, 14),
              paddingInlineStart: em(5, 14)
            },
            code: {
              fontSize: em(12, 14)
            },
            "h2 code": {
              fontSize: em(18, 20)
            },
            "h3 code": {
              fontSize: em(16, 18)
            },
            pre: {
              fontSize: em(12, 14),
              lineHeight: round(20 / 12),
              marginTop: em(20, 12),
              marginBottom: em(20, 12),
              borderRadius: rem(4),
              paddingTop: em(8, 12),
              paddingInlineEnd: em(12, 12),
              paddingBottom: em(8, 12),
              paddingInlineStart: em(12, 12)
            },
            ol: {
              marginTop: em(16, 14),
              marginBottom: em(16, 14),
              paddingInlineStart: em(22, 14)
            },
            ul: {
              marginTop: em(16, 14),
              marginBottom: em(16, 14),
              paddingInlineStart: em(22, 14)
            },
            li: {
              marginTop: em(4, 14),
              marginBottom: em(4, 14)
            },
            "ol > li": {
              paddingInlineStart: em(6, 14)
            },
            "ul > li": {
              paddingInlineStart: em(6, 14)
            },
            "> ul > li p": {
              marginTop: em(8, 14),
              marginBottom: em(8, 14)
            },
            "> ul > li > p:first-child": {
              marginTop: em(16, 14)
            },
            "> ul > li > p:last-child": {
              marginBottom: em(16, 14)
            },
            "> ol > li > p:first-child": {
              marginTop: em(16, 14)
            },
            "> ol > li > p:last-child": {
              marginBottom: em(16, 14)
            },
            "ul ul, ul ol, ol ul, ol ol": {
              marginTop: em(8, 14),
              marginBottom: em(8, 14)
            },
            dl: {
              marginTop: em(16, 14),
              marginBottom: em(16, 14)
            },
            dt: {
              marginTop: em(16, 14)
            },
            dd: {
              marginTop: em(4, 14),
              paddingInlineStart: em(22, 14)
            },
            hr: {
              marginTop: em(40, 14),
              marginBottom: em(40, 14)
            },
            "hr + *": {
              marginTop: "0"
            },
            "h2 + *": {
              marginTop: "0"
            },
            "h3 + *": {
              marginTop: "0"
            },
            "h4 + *": {
              marginTop: "0"
            },
            table: {
              fontSize: em(12, 14),
              lineHeight: round(18 / 12)
            },
            "thead th": {
              paddingInlineEnd: em(12, 12),
              paddingBottom: em(8, 12),
              paddingInlineStart: em(12, 12)
            },
            "thead th:first-child": {
              paddingInlineStart: "0"
            },
            "thead th:last-child": {
              paddingInlineEnd: "0"
            },
            "tbody td, tfoot td": {
              paddingTop: em(8, 12),
              paddingInlineEnd: em(12, 12),
              paddingBottom: em(8, 12),
              paddingInlineStart: em(12, 12)
            },
            "tbody td:first-child, tfoot td:first-child": {
              paddingInlineStart: "0"
            },
            "tbody td:last-child, tfoot td:last-child": {
              paddingInlineEnd: "0"
            },
            figure: {
              marginTop: em(24, 14),
              marginBottom: em(24, 14)
            },
            "figure > *": {
              marginTop: "0",
              marginBottom: "0"
            },
            figcaption: {
              fontSize: em(12, 14),
              lineHeight: round(16 / 12),
              marginTop: em(8, 12)
            }
          },
          {
            "> :first-child": {
              marginTop: "0"
            },
            "> :last-child": {
              marginBottom: "0"
            }
          }
        ]
      },
      base: {
        css: [
          {
            fontSize: rem(16),
            lineHeight: round(28 / 16),
            p: {
              marginTop: em(20, 16),
              marginBottom: em(20, 16)
            },
            '[class~="lead"]': {
              fontSize: em(20, 16),
              lineHeight: round(32 / 20),
              marginTop: em(24, 20),
              marginBottom: em(24, 20)
            },
            blockquote: {
              marginTop: em(32, 20),
              marginBottom: em(32, 20),
              paddingInlineStart: em(20, 20)
            },
            h1: {
              fontSize: em(36, 16),
              marginTop: "0",
              marginBottom: em(32, 36),
              lineHeight: round(40 / 36)
            },
            h2: {
              fontSize: em(24, 16),
              marginTop: em(48, 24),
              marginBottom: em(24, 24),
              lineHeight: round(32 / 24)
            },
            h3: {
              fontSize: em(20, 16),
              marginTop: em(32, 20),
              marginBottom: em(12, 20),
              lineHeight: round(32 / 20)
            },
            h4: {
              marginTop: em(24, 16),
              marginBottom: em(8, 16),
              lineHeight: round(24 / 16)
            },
            img: {
              marginTop: em(32, 16),
              marginBottom: em(32, 16)
            },
            picture: {
              marginTop: em(32, 16),
              marginBottom: em(32, 16)
            },
            "picture > img": {
              marginTop: "0",
              marginBottom: "0"
            },
            video: {
              marginTop: em(32, 16),
              marginBottom: em(32, 16)
            },
            kbd: {
              fontSize: em(14, 16),
              borderRadius: rem(5),
              paddingTop: em(3, 16),
              paddingInlineEnd: em(6, 16),
              paddingBottom: em(3, 16),
              paddingInlineStart: em(6, 16)
            },
            code: {
              fontSize: em(14, 16)
            },
            "h2 code": {
              fontSize: em(21, 24)
            },
            "h3 code": {
              fontSize: em(18, 20)
            },
            pre: {
              fontSize: em(14, 16),
              lineHeight: round(24 / 14),
              marginTop: em(24, 14),
              marginBottom: em(24, 14),
              borderRadius: rem(6),
              paddingTop: em(12, 14),
              paddingInlineEnd: em(16, 14),
              paddingBottom: em(12, 14),
              paddingInlineStart: em(16, 14)
            },
            ol: {
              marginTop: em(20, 16),
              marginBottom: em(20, 16),
              paddingInlineStart: em(26, 16)
            },
            ul: {
              marginTop: em(20, 16),
              marginBottom: em(20, 16),
              paddingInlineStart: em(26, 16)
            },
            li: {
              marginTop: em(8, 16),
              marginBottom: em(8, 16)
            },
            "ol > li": {
              paddingInlineStart: em(6, 16)
            },
            "ul > li": {
              paddingInlineStart: em(6, 16)
            },
            "> ul > li p": {
              marginTop: em(12, 16),
              marginBottom: em(12, 16)
            },
            "> ul > li > p:first-child": {
              marginTop: em(20, 16)
            },
            "> ul > li > p:last-child": {
              marginBottom: em(20, 16)
            },
            "> ol > li > p:first-child": {
              marginTop: em(20, 16)
            },
            "> ol > li > p:last-child": {
              marginBottom: em(20, 16)
            },
            "ul ul, ul ol, ol ul, ol ol": {
              marginTop: em(12, 16),
              marginBottom: em(12, 16)
            },
            dl: {
              marginTop: em(20, 16),
              marginBottom: em(20, 16)
            },
            dt: {
              marginTop: em(20, 16)
            },
            dd: {
              marginTop: em(8, 16),
              paddingInlineStart: em(26, 16)
            },
            hr: {
              marginTop: em(48, 16),
              marginBottom: em(48, 16)
            },
            "hr + *": {
              marginTop: "0"
            },
            "h2 + *": {
              marginTop: "0"
            },
            "h3 + *": {
              marginTop: "0"
            },
            "h4 + *": {
              marginTop: "0"
            },
            table: {
              fontSize: em(14, 16),
              lineHeight: round(24 / 14)
            },
            "thead th": {
              paddingInlineEnd: em(8, 14),
              paddingBottom: em(8, 14),
              paddingInlineStart: em(8, 14)
            },
            "thead th:first-child": {
              paddingInlineStart: "0"
            },
            "thead th:last-child": {
              paddingInlineEnd: "0"
            },
            "tbody td, tfoot td": {
              paddingTop: em(8, 14),
              paddingInlineEnd: em(8, 14),
              paddingBottom: em(8, 14),
              paddingInlineStart: em(8, 14)
            },
            "tbody td:first-child, tfoot td:first-child": {
              paddingInlineStart: "0"
            },
            "tbody td:last-child, tfoot td:last-child": {
              paddingInlineEnd: "0"
            },
            figure: {
              marginTop: em(32, 16),
              marginBottom: em(32, 16)
            },
            "figure > *": {
              marginTop: "0",
              marginBottom: "0"
            },
            figcaption: {
              fontSize: em(14, 16),
              lineHeight: round(20 / 14),
              marginTop: em(12, 14)
            }
          },
          {
            "> :first-child": {
              marginTop: "0"
            },
            "> :last-child": {
              marginBottom: "0"
            }
          }
        ]
      },
      lg: {
        css: [
          {
            fontSize: rem(18),
            lineHeight: round(32 / 18),
            p: {
              marginTop: em(24, 18),
              marginBottom: em(24, 18)
            },
            '[class~="lead"]': {
              fontSize: em(22, 18),
              lineHeight: round(32 / 22),
              marginTop: em(24, 22),
              marginBottom: em(24, 22)
            },
            blockquote: {
              marginTop: em(40, 24),
              marginBottom: em(40, 24),
              paddingInlineStart: em(24, 24)
            },
            h1: {
              fontSize: em(48, 18),
              marginTop: "0",
              marginBottom: em(40, 48),
              lineHeight: round(48 / 48)
            },
            h2: {
              fontSize: em(30, 18),
              marginTop: em(56, 30),
              marginBottom: em(32, 30),
              lineHeight: round(40 / 30)
            },
            h3: {
              fontSize: em(24, 18),
              marginTop: em(40, 24),
              marginBottom: em(16, 24),
              lineHeight: round(36 / 24)
            },
            h4: {
              marginTop: em(32, 18),
              marginBottom: em(8, 18),
              lineHeight: round(28 / 18)
            },
            img: {
              marginTop: em(32, 18),
              marginBottom: em(32, 18)
            },
            picture: {
              marginTop: em(32, 18),
              marginBottom: em(32, 18)
            },
            "picture > img": {
              marginTop: "0",
              marginBottom: "0"
            },
            video: {
              marginTop: em(32, 18),
              marginBottom: em(32, 18)
            },
            kbd: {
              fontSize: em(16, 18),
              borderRadius: rem(5),
              paddingTop: em(4, 18),
              paddingInlineEnd: em(8, 18),
              paddingBottom: em(4, 18),
              paddingInlineStart: em(8, 18)
            },
            code: {
              fontSize: em(16, 18)
            },
            "h2 code": {
              fontSize: em(26, 30)
            },
            "h3 code": {
              fontSize: em(21, 24)
            },
            pre: {
              fontSize: em(16, 18),
              lineHeight: round(28 / 16),
              marginTop: em(32, 16),
              marginBottom: em(32, 16),
              borderRadius: rem(6),
              paddingTop: em(16, 16),
              paddingInlineEnd: em(24, 16),
              paddingBottom: em(16, 16),
              paddingInlineStart: em(24, 16)
            },
            ol: {
              marginTop: em(24, 18),
              marginBottom: em(24, 18),
              paddingInlineStart: em(28, 18)
            },
            ul: {
              marginTop: em(24, 18),
              marginBottom: em(24, 18),
              paddingInlineStart: em(28, 18)
            },
            li: {
              marginTop: em(12, 18),
              marginBottom: em(12, 18)
            },
            "ol > li": {
              paddingInlineStart: em(8, 18)
            },
            "ul > li": {
              paddingInlineStart: em(8, 18)
            },
            "> ul > li p": {
              marginTop: em(16, 18),
              marginBottom: em(16, 18)
            },
            "> ul > li > p:first-child": {
              marginTop: em(24, 18)
            },
            "> ul > li > p:last-child": {
              marginBottom: em(24, 18)
            },
            "> ol > li > p:first-child": {
              marginTop: em(24, 18)
            },
            "> ol > li > p:last-child": {
              marginBottom: em(24, 18)
            },
            "ul ul, ul ol, ol ul, ol ol": {
              marginTop: em(16, 18),
              marginBottom: em(16, 18)
            },
            dl: {
              marginTop: em(24, 18),
              marginBottom: em(24, 18)
            },
            dt: {
              marginTop: em(24, 18)
            },
            dd: {
              marginTop: em(12, 18),
              paddingInlineStart: em(28, 18)
            },
            hr: {
              marginTop: em(56, 18),
              marginBottom: em(56, 18)
            },
            "hr + *": {
              marginTop: "0"
            },
            "h2 + *": {
              marginTop: "0"
            },
            "h3 + *": {
              marginTop: "0"
            },
            "h4 + *": {
              marginTop: "0"
            },
            table: {
              fontSize: em(16, 18),
              lineHeight: round(24 / 16)
            },
            "thead th": {
              paddingInlineEnd: em(12, 16),
              paddingBottom: em(12, 16),
              paddingInlineStart: em(12, 16)
            },
            "thead th:first-child": {
              paddingInlineStart: "0"
            },
            "thead th:last-child": {
              paddingInlineEnd: "0"
            },
            "tbody td, tfoot td": {
              paddingTop: em(12, 16),
              paddingInlineEnd: em(12, 16),
              paddingBottom: em(12, 16),
              paddingInlineStart: em(12, 16)
            },
            "tbody td:first-child, tfoot td:first-child": {
              paddingInlineStart: "0"
            },
            "tbody td:last-child, tfoot td:last-child": {
              paddingInlineEnd: "0"
            },
            figure: {
              marginTop: em(32, 18),
              marginBottom: em(32, 18)
            },
            "figure > *": {
              marginTop: "0",
              marginBottom: "0"
            },
            figcaption: {
              fontSize: em(16, 18),
              lineHeight: round(24 / 16),
              marginTop: em(16, 16)
            }
          },
          {
            "> :first-child": {
              marginTop: "0"
            },
            "> :last-child": {
              marginBottom: "0"
            }
          }
        ]
      },
      xl: {
        css: [
          {
            fontSize: rem(20),
            lineHeight: round(36 / 20),
            p: {
              marginTop: em(24, 20),
              marginBottom: em(24, 20)
            },
            '[class~="lead"]': {
              fontSize: em(24, 20),
              lineHeight: round(36 / 24),
              marginTop: em(24, 24),
              marginBottom: em(24, 24)
            },
            blockquote: {
              marginTop: em(48, 30),
              marginBottom: em(48, 30),
              paddingInlineStart: em(32, 30)
            },
            h1: {
              fontSize: em(56, 20),
              marginTop: "0",
              marginBottom: em(48, 56),
              lineHeight: round(56 / 56)
            },
            h2: {
              fontSize: em(36, 20),
              marginTop: em(56, 36),
              marginBottom: em(32, 36),
              lineHeight: round(40 / 36)
            },
            h3: {
              fontSize: em(30, 20),
              marginTop: em(48, 30),
              marginBottom: em(20, 30),
              lineHeight: round(40 / 30)
            },
            h4: {
              marginTop: em(36, 20),
              marginBottom: em(12, 20),
              lineHeight: round(32 / 20)
            },
            img: {
              marginTop: em(40, 20),
              marginBottom: em(40, 20)
            },
            picture: {
              marginTop: em(40, 20),
              marginBottom: em(40, 20)
            },
            "picture > img": {
              marginTop: "0",
              marginBottom: "0"
            },
            video: {
              marginTop: em(40, 20),
              marginBottom: em(40, 20)
            },
            kbd: {
              fontSize: em(18, 20),
              borderRadius: rem(5),
              paddingTop: em(5, 20),
              paddingInlineEnd: em(8, 20),
              paddingBottom: em(5, 20),
              paddingInlineStart: em(8, 20)
            },
            code: {
              fontSize: em(18, 20)
            },
            "h2 code": {
              fontSize: em(31, 36)
            },
            "h3 code": {
              fontSize: em(27, 30)
            },
            pre: {
              fontSize: em(18, 20),
              lineHeight: round(32 / 18),
              marginTop: em(36, 18),
              marginBottom: em(36, 18),
              borderRadius: rem(8),
              paddingTop: em(20, 18),
              paddingInlineEnd: em(24, 18),
              paddingBottom: em(20, 18),
              paddingInlineStart: em(24, 18)
            },
            ol: {
              marginTop: em(24, 20),
              marginBottom: em(24, 20),
              paddingInlineStart: em(32, 20)
            },
            ul: {
              marginTop: em(24, 20),
              marginBottom: em(24, 20),
              paddingInlineStart: em(32, 20)
            },
            li: {
              marginTop: em(12, 20),
              marginBottom: em(12, 20)
            },
            "ol > li": {
              paddingInlineStart: em(8, 20)
            },
            "ul > li": {
              paddingInlineStart: em(8, 20)
            },
            "> ul > li p": {
              marginTop: em(16, 20),
              marginBottom: em(16, 20)
            },
            "> ul > li > p:first-child": {
              marginTop: em(24, 20)
            },
            "> ul > li > p:last-child": {
              marginBottom: em(24, 20)
            },
            "> ol > li > p:first-child": {
              marginTop: em(24, 20)
            },
            "> ol > li > p:last-child": {
              marginBottom: em(24, 20)
            },
            "ul ul, ul ol, ol ul, ol ol": {
              marginTop: em(16, 20),
              marginBottom: em(16, 20)
            },
            dl: {
              marginTop: em(24, 20),
              marginBottom: em(24, 20)
            },
            dt: {
              marginTop: em(24, 20)
            },
            dd: {
              marginTop: em(12, 20),
              paddingInlineStart: em(32, 20)
            },
            hr: {
              marginTop: em(56, 20),
              marginBottom: em(56, 20)
            },
            "hr + *": {
              marginTop: "0"
            },
            "h2 + *": {
              marginTop: "0"
            },
            "h3 + *": {
              marginTop: "0"
            },
            "h4 + *": {
              marginTop: "0"
            },
            table: {
              fontSize: em(18, 20),
              lineHeight: round(28 / 18)
            },
            "thead th": {
              paddingInlineEnd: em(12, 18),
              paddingBottom: em(16, 18),
              paddingInlineStart: em(12, 18)
            },
            "thead th:first-child": {
              paddingInlineStart: "0"
            },
            "thead th:last-child": {
              paddingInlineEnd: "0"
            },
            "tbody td, tfoot td": {
              paddingTop: em(16, 18),
              paddingInlineEnd: em(12, 18),
              paddingBottom: em(16, 18),
              paddingInlineStart: em(12, 18)
            },
            "tbody td:first-child, tfoot td:first-child": {
              paddingInlineStart: "0"
            },
            "tbody td:last-child, tfoot td:last-child": {
              paddingInlineEnd: "0"
            },
            figure: {
              marginTop: em(40, 20),
              marginBottom: em(40, 20)
            },
            "figure > *": {
              marginTop: "0",
              marginBottom: "0"
            },
            figcaption: {
              fontSize: em(18, 20),
              lineHeight: round(28 / 18),
              marginTop: em(18, 18)
            }
          },
          {
            "> :first-child": {
              marginTop: "0"
            },
            "> :last-child": {
              marginBottom: "0"
            }
          }
        ]
      },
      "2xl": {
        css: [
          {
            fontSize: rem(24),
            lineHeight: round(40 / 24),
            p: {
              marginTop: em(32, 24),
              marginBottom: em(32, 24)
            },
            '[class~="lead"]': {
              fontSize: em(30, 24),
              lineHeight: round(44 / 30),
              marginTop: em(32, 30),
              marginBottom: em(32, 30)
            },
            blockquote: {
              marginTop: em(64, 36),
              marginBottom: em(64, 36),
              paddingInlineStart: em(40, 36)
            },
            h1: {
              fontSize: em(64, 24),
              marginTop: "0",
              marginBottom: em(56, 64),
              lineHeight: round(64 / 64)
            },
            h2: {
              fontSize: em(48, 24),
              marginTop: em(72, 48),
              marginBottom: em(40, 48),
              lineHeight: round(52 / 48)
            },
            h3: {
              fontSize: em(36, 24),
              marginTop: em(56, 36),
              marginBottom: em(24, 36),
              lineHeight: round(44 / 36)
            },
            h4: {
              marginTop: em(40, 24),
              marginBottom: em(16, 24),
              lineHeight: round(36 / 24)
            },
            img: {
              marginTop: em(48, 24),
              marginBottom: em(48, 24)
            },
            picture: {
              marginTop: em(48, 24),
              marginBottom: em(48, 24)
            },
            "picture > img": {
              marginTop: "0",
              marginBottom: "0"
            },
            video: {
              marginTop: em(48, 24),
              marginBottom: em(48, 24)
            },
            kbd: {
              fontSize: em(20, 24),
              borderRadius: rem(6),
              paddingTop: em(6, 24),
              paddingInlineEnd: em(8, 24),
              paddingBottom: em(6, 24),
              paddingInlineStart: em(8, 24)
            },
            code: {
              fontSize: em(20, 24)
            },
            "h2 code": {
              fontSize: em(42, 48)
            },
            "h3 code": {
              fontSize: em(32, 36)
            },
            pre: {
              fontSize: em(20, 24),
              lineHeight: round(36 / 20),
              marginTop: em(40, 20),
              marginBottom: em(40, 20),
              borderRadius: rem(8),
              paddingTop: em(24, 20),
              paddingInlineEnd: em(32, 20),
              paddingBottom: em(24, 20),
              paddingInlineStart: em(32, 20)
            },
            ol: {
              marginTop: em(32, 24),
              marginBottom: em(32, 24),
              paddingInlineStart: em(38, 24)
            },
            ul: {
              marginTop: em(32, 24),
              marginBottom: em(32, 24),
              paddingInlineStart: em(38, 24)
            },
            li: {
              marginTop: em(12, 24),
              marginBottom: em(12, 24)
            },
            "ol > li": {
              paddingInlineStart: em(10, 24)
            },
            "ul > li": {
              paddingInlineStart: em(10, 24)
            },
            "> ul > li p": {
              marginTop: em(20, 24),
              marginBottom: em(20, 24)
            },
            "> ul > li > p:first-child": {
              marginTop: em(32, 24)
            },
            "> ul > li > p:last-child": {
              marginBottom: em(32, 24)
            },
            "> ol > li > p:first-child": {
              marginTop: em(32, 24)
            },
            "> ol > li > p:last-child": {
              marginBottom: em(32, 24)
            },
            "ul ul, ul ol, ol ul, ol ol": {
              marginTop: em(16, 24),
              marginBottom: em(16, 24)
            },
            dl: {
              marginTop: em(32, 24),
              marginBottom: em(32, 24)
            },
            dt: {
              marginTop: em(32, 24)
            },
            dd: {
              marginTop: em(12, 24),
              paddingInlineStart: em(38, 24)
            },
            hr: {
              marginTop: em(72, 24),
              marginBottom: em(72, 24)
            },
            "hr + *": {
              marginTop: "0"
            },
            "h2 + *": {
              marginTop: "0"
            },
            "h3 + *": {
              marginTop: "0"
            },
            "h4 + *": {
              marginTop: "0"
            },
            table: {
              fontSize: em(20, 24),
              lineHeight: round(28 / 20)
            },
            "thead th": {
              paddingInlineEnd: em(12, 20),
              paddingBottom: em(16, 20),
              paddingInlineStart: em(12, 20)
            },
            "thead th:first-child": {
              paddingInlineStart: "0"
            },
            "thead th:last-child": {
              paddingInlineEnd: "0"
            },
            "tbody td, tfoot td": {
              paddingTop: em(16, 20),
              paddingInlineEnd: em(12, 20),
              paddingBottom: em(16, 20),
              paddingInlineStart: em(12, 20)
            },
            "tbody td:first-child, tfoot td:first-child": {
              paddingInlineStart: "0"
            },
            "tbody td:last-child, tfoot td:last-child": {
              paddingInlineEnd: "0"
            },
            figure: {
              marginTop: em(48, 24),
              marginBottom: em(48, 24)
            },
            "figure > *": {
              marginTop: "0",
              marginBottom: "0"
            },
            figcaption: {
              fontSize: em(20, 24),
              lineHeight: round(32 / 20),
              marginTop: em(20, 20)
            }
          },
          {
            "> :first-child": {
              marginTop: "0"
            },
            "> :last-child": {
              marginBottom: "0"
            }
          }
        ]
      },
      // Gray color themes
      slate: {
        css: {
          "--tw-prose-body": colors.slate[700],
          "--tw-prose-headings": colors.slate[900],
          "--tw-prose-lead": colors.slate[600],
          "--tw-prose-links": colors.slate[900],
          "--tw-prose-bold": colors.slate[900],
          "--tw-prose-counters": colors.slate[500],
          "--tw-prose-bullets": colors.slate[300],
          "--tw-prose-hr": colors.slate[200],
          "--tw-prose-quotes": colors.slate[900],
          "--tw-prose-quote-borders": colors.slate[200],
          "--tw-prose-captions": colors.slate[500],
          "--tw-prose-kbd": colors.slate[900],
          "--tw-prose-kbd-shadows": hexToRgb(colors.slate[900]),
          "--tw-prose-code": colors.slate[900],
          "--tw-prose-pre-code": colors.slate[200],
          "--tw-prose-pre-bg": colors.slate[800],
          "--tw-prose-th-borders": colors.slate[300],
          "--tw-prose-td-borders": colors.slate[200],
          "--tw-prose-invert-body": colors.slate[300],
          "--tw-prose-invert-headings": colors.white,
          "--tw-prose-invert-lead": colors.slate[400],
          "--tw-prose-invert-links": colors.white,
          "--tw-prose-invert-bold": colors.white,
          "--tw-prose-invert-counters": colors.slate[400],
          "--tw-prose-invert-bullets": colors.slate[600],
          "--tw-prose-invert-hr": colors.slate[700],
          "--tw-prose-invert-quotes": colors.slate[100],
          "--tw-prose-invert-quote-borders": colors.slate[700],
          "--tw-prose-invert-captions": colors.slate[400],
          "--tw-prose-invert-kbd": colors.white,
          "--tw-prose-invert-kbd-shadows": hexToRgb(colors.white),
          "--tw-prose-invert-code": colors.white,
          "--tw-prose-invert-pre-code": colors.slate[300],
          "--tw-prose-invert-pre-bg": "rgb(0 0 0 / 50%)",
          "--tw-prose-invert-th-borders": colors.slate[600],
          "--tw-prose-invert-td-borders": colors.slate[700]
        }
      },
      gray: {
        css: {
          "--tw-prose-body": colors.gray[700],
          "--tw-prose-headings": colors.gray[900],
          "--tw-prose-lead": colors.gray[600],
          "--tw-prose-links": colors.gray[900],
          "--tw-prose-bold": colors.gray[900],
          "--tw-prose-counters": colors.gray[500],
          "--tw-prose-bullets": colors.gray[300],
          "--tw-prose-hr": colors.gray[200],
          "--tw-prose-quotes": colors.gray[900],
          "--tw-prose-quote-borders": colors.gray[200],
          "--tw-prose-captions": colors.gray[500],
          "--tw-prose-kbd": colors.gray[900],
          "--tw-prose-kbd-shadows": hexToRgb(colors.gray[900]),
          "--tw-prose-code": colors.gray[900],
          "--tw-prose-pre-code": colors.gray[200],
          "--tw-prose-pre-bg": colors.gray[800],
          "--tw-prose-th-borders": colors.gray[300],
          "--tw-prose-td-borders": colors.gray[200],
          "--tw-prose-invert-body": colors.gray[300],
          "--tw-prose-invert-headings": colors.white,
          "--tw-prose-invert-lead": colors.gray[400],
          "--tw-prose-invert-links": colors.white,
          "--tw-prose-invert-bold": colors.white,
          "--tw-prose-invert-counters": colors.gray[400],
          "--tw-prose-invert-bullets": colors.gray[600],
          "--tw-prose-invert-hr": colors.gray[700],
          "--tw-prose-invert-quotes": colors.gray[100],
          "--tw-prose-invert-quote-borders": colors.gray[700],
          "--tw-prose-invert-captions": colors.gray[400],
          "--tw-prose-invert-kbd": colors.white,
          "--tw-prose-invert-kbd-shadows": hexToRgb(colors.white),
          "--tw-prose-invert-code": colors.white,
          "--tw-prose-invert-pre-code": colors.gray[300],
          "--tw-prose-invert-pre-bg": "rgb(0 0 0 / 50%)",
          "--tw-prose-invert-th-borders": colors.gray[600],
          "--tw-prose-invert-td-borders": colors.gray[700]
        }
      },
      zinc: {
        css: {
          "--tw-prose-body": colors.zinc[700],
          "--tw-prose-headings": colors.zinc[900],
          "--tw-prose-lead": colors.zinc[600],
          "--tw-prose-links": colors.zinc[900],
          "--tw-prose-bold": colors.zinc[900],
          "--tw-prose-counters": colors.zinc[500],
          "--tw-prose-bullets": colors.zinc[300],
          "--tw-prose-hr": colors.zinc[200],
          "--tw-prose-quotes": colors.zinc[900],
          "--tw-prose-quote-borders": colors.zinc[200],
          "--tw-prose-captions": colors.zinc[500],
          "--tw-prose-kbd": colors.zinc[900],
          "--tw-prose-kbd-shadows": hexToRgb(colors.zinc[900]),
          "--tw-prose-code": colors.zinc[900],
          "--tw-prose-pre-code": colors.zinc[200],
          "--tw-prose-pre-bg": colors.zinc[800],
          "--tw-prose-th-borders": colors.zinc[300],
          "--tw-prose-td-borders": colors.zinc[200],
          "--tw-prose-invert-body": colors.zinc[300],
          "--tw-prose-invert-headings": colors.white,
          "--tw-prose-invert-lead": colors.zinc[400],
          "--tw-prose-invert-links": colors.white,
          "--tw-prose-invert-bold": colors.white,
          "--tw-prose-invert-counters": colors.zinc[400],
          "--tw-prose-invert-bullets": colors.zinc[600],
          "--tw-prose-invert-hr": colors.zinc[700],
          "--tw-prose-invert-quotes": colors.zinc[100],
          "--tw-prose-invert-quote-borders": colors.zinc[700],
          "--tw-prose-invert-captions": colors.zinc[400],
          "--tw-prose-invert-kbd": colors.white,
          "--tw-prose-invert-kbd-shadows": hexToRgb(colors.white),
          "--tw-prose-invert-code": colors.white,
          "--tw-prose-invert-pre-code": colors.zinc[300],
          "--tw-prose-invert-pre-bg": "rgb(0 0 0 / 50%)",
          "--tw-prose-invert-th-borders": colors.zinc[600],
          "--tw-prose-invert-td-borders": colors.zinc[700]
        }
      },
      neutral: {
        css: {
          "--tw-prose-body": colors.neutral[700],
          "--tw-prose-headings": colors.neutral[900],
          "--tw-prose-lead": colors.neutral[600],
          "--tw-prose-links": colors.neutral[900],
          "--tw-prose-bold": colors.neutral[900],
          "--tw-prose-counters": colors.neutral[500],
          "--tw-prose-bullets": colors.neutral[300],
          "--tw-prose-hr": colors.neutral[200],
          "--tw-prose-quotes": colors.neutral[900],
          "--tw-prose-quote-borders": colors.neutral[200],
          "--tw-prose-captions": colors.neutral[500],
          "--tw-prose-kbd": colors.neutral[900],
          "--tw-prose-kbd-shadows": hexToRgb(colors.neutral[900]),
          "--tw-prose-code": colors.neutral[900],
          "--tw-prose-pre-code": colors.neutral[200],
          "--tw-prose-pre-bg": colors.neutral[800],
          "--tw-prose-th-borders": colors.neutral[300],
          "--tw-prose-td-borders": colors.neutral[200],
          "--tw-prose-invert-body": colors.neutral[300],
          "--tw-prose-invert-headings": colors.white,
          "--tw-prose-invert-lead": colors.neutral[400],
          "--tw-prose-invert-links": colors.white,
          "--tw-prose-invert-bold": colors.white,
          "--tw-prose-invert-counters": colors.neutral[400],
          "--tw-prose-invert-bullets": colors.neutral[600],
          "--tw-prose-invert-hr": colors.neutral[700],
          "--tw-prose-invert-quotes": colors.neutral[100],
          "--tw-prose-invert-quote-borders": colors.neutral[700],
          "--tw-prose-invert-captions": colors.neutral[400],
          "--tw-prose-invert-kbd": colors.white,
          "--tw-prose-invert-kbd-shadows": hexToRgb(colors.white),
          "--tw-prose-invert-code": colors.white,
          "--tw-prose-invert-pre-code": colors.neutral[300],
          "--tw-prose-invert-pre-bg": "rgb(0 0 0 / 50%)",
          "--tw-prose-invert-th-borders": colors.neutral[600],
          "--tw-prose-invert-td-borders": colors.neutral[700]
        }
      },
      stone: {
        css: {
          "--tw-prose-body": colors.stone[700],
          "--tw-prose-headings": colors.stone[900],
          "--tw-prose-lead": colors.stone[600],
          "--tw-prose-links": colors.stone[900],
          "--tw-prose-bold": colors.stone[900],
          "--tw-prose-counters": colors.stone[500],
          "--tw-prose-bullets": colors.stone[300],
          "--tw-prose-hr": colors.stone[200],
          "--tw-prose-quotes": colors.stone[900],
          "--tw-prose-quote-borders": colors.stone[200],
          "--tw-prose-captions": colors.stone[500],
          "--tw-prose-kbd": colors.stone[900],
          "--tw-prose-kbd-shadows": hexToRgb(colors.stone[900]),
          "--tw-prose-code": colors.stone[900],
          "--tw-prose-pre-code": colors.stone[200],
          "--tw-prose-pre-bg": colors.stone[800],
          "--tw-prose-th-borders": colors.stone[300],
          "--tw-prose-td-borders": colors.stone[200],
          "--tw-prose-invert-body": colors.stone[300],
          "--tw-prose-invert-headings": colors.white,
          "--tw-prose-invert-lead": colors.stone[400],
          "--tw-prose-invert-links": colors.white,
          "--tw-prose-invert-bold": colors.white,
          "--tw-prose-invert-counters": colors.stone[400],
          "--tw-prose-invert-bullets": colors.stone[600],
          "--tw-prose-invert-hr": colors.stone[700],
          "--tw-prose-invert-quotes": colors.stone[100],
          "--tw-prose-invert-quote-borders": colors.stone[700],
          "--tw-prose-invert-captions": colors.stone[400],
          "--tw-prose-invert-kbd": colors.white,
          "--tw-prose-invert-kbd-shadows": hexToRgb(colors.white),
          "--tw-prose-invert-code": colors.white,
          "--tw-prose-invert-pre-code": colors.stone[300],
          "--tw-prose-invert-pre-bg": "rgb(0 0 0 / 50%)",
          "--tw-prose-invert-th-borders": colors.stone[600],
          "--tw-prose-invert-td-borders": colors.stone[700]
        }
      },
      // Link-only themes (for backward compatibility)
      red: {
        css: {
          "--tw-prose-links": colors.red[600],
          "--tw-prose-invert-links": colors.red[500]
        }
      },
      orange: {
        css: {
          "--tw-prose-links": colors.orange[600],
          "--tw-prose-invert-links": colors.orange[500]
        }
      },
      amber: {
        css: {
          "--tw-prose-links": colors.amber[600],
          "--tw-prose-invert-links": colors.amber[500]
        }
      },
      yellow: {
        css: {
          "--tw-prose-links": colors.yellow[600],
          "--tw-prose-invert-links": colors.yellow[500]
        }
      },
      lime: {
        css: {
          "--tw-prose-links": colors.lime[600],
          "--tw-prose-invert-links": colors.lime[500]
        }
      },
      green: {
        css: {
          "--tw-prose-links": colors.green[600],
          "--tw-prose-invert-links": colors.green[500]
        }
      },
      emerald: {
        css: {
          "--tw-prose-links": colors.emerald[600],
          "--tw-prose-invert-links": colors.emerald[500]
        }
      },
      teal: {
        css: {
          "--tw-prose-links": colors.teal[600],
          "--tw-prose-invert-links": colors.teal[500]
        }
      },
      cyan: {
        css: {
          "--tw-prose-links": colors.cyan[600],
          "--tw-prose-invert-links": colors.cyan[500]
        }
      },
      sky: {
        css: {
          "--tw-prose-links": colors.sky[600],
          "--tw-prose-invert-links": colors.sky[500]
        }
      },
      blue: {
        css: {
          "--tw-prose-links": colors.blue[600],
          "--tw-prose-invert-links": colors.blue[500]
        }
      },
      indigo: {
        css: {
          "--tw-prose-links": colors.indigo[600],
          "--tw-prose-invert-links": colors.indigo[500]
        }
      },
      violet: {
        css: {
          "--tw-prose-links": colors.violet[600],
          "--tw-prose-invert-links": colors.violet[500]
        }
      },
      purple: {
        css: {
          "--tw-prose-links": colors.purple[600],
          "--tw-prose-invert-links": colors.purple[500]
        }
      },
      fuchsia: {
        css: {
          "--tw-prose-links": colors.fuchsia[600],
          "--tw-prose-invert-links": colors.fuchsia[500]
        }
      },
      pink: {
        css: {
          "--tw-prose-links": colors.pink[600],
          "--tw-prose-invert-links": colors.pink[500]
        }
      },
      rose: {
        css: {
          "--tw-prose-links": colors.rose[600],
          "--tw-prose-invert-links": colors.rose[500]
        }
      },
      // Invert (for dark mode)
      invert: {
        css: {
          "--tw-prose-body": "var(--tw-prose-invert-body)",
          "--tw-prose-headings": "var(--tw-prose-invert-headings)",
          "--tw-prose-lead": "var(--tw-prose-invert-lead)",
          "--tw-prose-links": "var(--tw-prose-invert-links)",
          "--tw-prose-bold": "var(--tw-prose-invert-bold)",
          "--tw-prose-counters": "var(--tw-prose-invert-counters)",
          "--tw-prose-bullets": "var(--tw-prose-invert-bullets)",
          "--tw-prose-hr": "var(--tw-prose-invert-hr)",
          "--tw-prose-quotes": "var(--tw-prose-invert-quotes)",
          "--tw-prose-quote-borders": "var(--tw-prose-invert-quote-borders)",
          "--tw-prose-captions": "var(--tw-prose-invert-captions)",
          "--tw-prose-kbd": "var(--tw-prose-invert-kbd)",
          "--tw-prose-kbd-shadows": "var(--tw-prose-invert-kbd-shadows)",
          "--tw-prose-code": "var(--tw-prose-invert-code)",
          "--tw-prose-pre-code": "var(--tw-prose-invert-pre-code)",
          "--tw-prose-pre-bg": "var(--tw-prose-invert-pre-bg)",
          "--tw-prose-th-borders": "var(--tw-prose-invert-th-borders)",
          "--tw-prose-td-borders": "var(--tw-prose-invert-td-borders)"
        }
      }
    };
    module.exports = {
      DEFAULT: {
        css: [
          {
            color: "var(--tw-prose-body)",
            maxWidth: "65ch",
            p: {},
            // Required to maintain correct order when merging
            '[class~="lead"]': {
              color: "var(--tw-prose-lead)"
            },
            a: {
              color: "var(--tw-prose-links)",
              textDecoration: "underline",
              fontWeight: "500"
            },
            strong: {
              color: "var(--tw-prose-bold)",
              fontWeight: "600"
            },
            "a strong": {
              color: "inherit"
            },
            "blockquote strong": {
              color: "inherit"
            },
            "thead th strong": {
              color: "inherit"
            },
            ol: {
              listStyleType: "decimal"
            },
            'ol[type="A"]': {
              listStyleType: "upper-alpha"
            },
            'ol[type="a"]': {
              listStyleType: "lower-alpha"
            },
            'ol[type="A" s]': {
              listStyleType: "upper-alpha"
            },
            'ol[type="a" s]': {
              listStyleType: "lower-alpha"
            },
            'ol[type="I"]': {
              listStyleType: "upper-roman"
            },
            'ol[type="i"]': {
              listStyleType: "lower-roman"
            },
            'ol[type="I" s]': {
              listStyleType: "upper-roman"
            },
            'ol[type="i" s]': {
              listStyleType: "lower-roman"
            },
            'ol[type="1"]': {
              listStyleType: "decimal"
            },
            ul: {
              listStyleType: "disc"
            },
            "ol > li::marker": {
              fontWeight: "400",
              color: "var(--tw-prose-counters)"
            },
            "ul > li::marker": {
              color: "var(--tw-prose-bullets)"
            },
            dt: {
              color: "var(--tw-prose-headings)",
              fontWeight: "600"
            },
            hr: {
              borderColor: "var(--tw-prose-hr)",
              borderTopWidth: 1
            },
            blockquote: {
              fontWeight: "500",
              fontStyle: "italic",
              color: "var(--tw-prose-quotes)",
              borderInlineStartWidth: "0.25rem",
              borderInlineStartColor: "var(--tw-prose-quote-borders)",
              quotes: '"\\201C""\\201D""\\2018""\\2019"'
            },
            "blockquote p:first-of-type::before": {
              content: "open-quote"
            },
            "blockquote p:last-of-type::after": {
              content: "close-quote"
            },
            h1: {
              color: "var(--tw-prose-headings)",
              fontWeight: "800"
            },
            "h1 strong": {
              fontWeight: "900",
              color: "inherit"
            },
            h2: {
              color: "var(--tw-prose-headings)",
              fontWeight: "700"
            },
            "h2 strong": {
              fontWeight: "800",
              color: "inherit"
            },
            h3: {
              color: "var(--tw-prose-headings)",
              fontWeight: "600"
            },
            "h3 strong": {
              fontWeight: "700",
              color: "inherit"
            },
            h4: {
              color: "var(--tw-prose-headings)",
              fontWeight: "600"
            },
            "h4 strong": {
              fontWeight: "700",
              color: "inherit"
            },
            img: {},
            // Required to maintain correct order when merging
            picture: {
              display: "block"
            },
            video: {},
            // Required to maintain correct order when merging
            kbd: {
              fontWeight: "500",
              fontFamily: "inherit",
              color: "var(--tw-prose-kbd)",
              boxShadow: "0 0 0 1px rgb(var(--tw-prose-kbd-shadows) / 10%), 0 3px 0 rgb(var(--tw-prose-kbd-shadows) / 10%)"
            },
            code: {
              color: "var(--tw-prose-code)",
              fontWeight: "600"
            },
            "code::before": {
              content: '"`"'
            },
            "code::after": {
              content: '"`"'
            },
            "a code": {
              color: "inherit"
            },
            "h1 code": {
              color: "inherit"
            },
            "h2 code": {
              color: "inherit"
            },
            "h3 code": {
              color: "inherit"
            },
            "h4 code": {
              color: "inherit"
            },
            "blockquote code": {
              color: "inherit"
            },
            "thead th code": {
              color: "inherit"
            },
            pre: {
              color: "var(--tw-prose-pre-code)",
              backgroundColor: "var(--tw-prose-pre-bg)",
              overflowX: "auto",
              fontWeight: "400"
            },
            "pre code": {
              backgroundColor: "transparent",
              borderWidth: "0",
              borderRadius: "0",
              padding: "0",
              fontWeight: "inherit",
              color: "inherit",
              fontSize: "inherit",
              fontFamily: "inherit",
              lineHeight: "inherit"
            },
            "pre code::before": {
              content: "none"
            },
            "pre code::after": {
              content: "none"
            },
            table: {
              width: "100%",
              tableLayout: "auto",
              marginTop: em(32, 16),
              marginBottom: em(32, 16)
            },
            thead: {
              borderBottomWidth: "1px",
              borderBottomColor: "var(--tw-prose-th-borders)"
            },
            "thead th": {
              color: "var(--tw-prose-headings)",
              fontWeight: "600",
              verticalAlign: "bottom"
            },
            "tbody tr": {
              borderBottomWidth: "1px",
              borderBottomColor: "var(--tw-prose-td-borders)"
            },
            "tbody tr:last-child": {
              borderBottomWidth: "0"
            },
            "tbody td": {
              verticalAlign: "baseline"
            },
            tfoot: {
              borderTopWidth: "1px",
              borderTopColor: "var(--tw-prose-th-borders)"
            },
            "tfoot td": {
              verticalAlign: "top"
            },
            "th, td": {
              textAlign: "start"
            },
            "figure > *": {},
            // Required to maintain correct order when merging
            figcaption: {
              color: "var(--tw-prose-captions)"
            }
          },
          defaultModifiers.gray.css,
          ...defaultModifiers.base.css
        ]
      },
      ...defaultModifiers
    };
  }
});

// node_modules/lodash.isplainobject/index.js
var require_lodash3 = __commonJS({
  "node_modules/lodash.isplainobject/index.js"(exports, module) {
    var objectTag = "[object Object]";
    function isHostObject(value) {
      var result = false;
      if (value != null && typeof value.toString != "function") {
        try {
          result = !!(value + "");
        } catch (e) {
        }
      }
      return result;
    }
    function overArg(func, transform) {
      return function(arg) {
        return func(transform(arg));
      };
    }
    var funcProto = Function.prototype;
    var objectProto = Object.prototype;
    var funcToString = funcProto.toString;
    var hasOwnProperty = objectProto.hasOwnProperty;
    var objectCtorString = funcToString.call(Object);
    var objectToString = objectProto.toString;
    var getPrototype = overArg(Object.getPrototypeOf, Object);
    function isObjectLike(value) {
      return !!value && typeof value == "object";
    }
    function isPlainObject(value) {
      if (!isObjectLike(value) || objectToString.call(value) != objectTag || isHostObject(value)) {
        return false;
      }
      var proto = getPrototype(value);
      if (proto === null) {
        return true;
      }
      var Ctor = hasOwnProperty.call(proto, "constructor") && proto.constructor;
      return typeof Ctor == "function" && Ctor instanceof Ctor && funcToString.call(Ctor) == objectCtorString;
    }
    module.exports = isPlainObject;
  }
});

// node_modules/postcss-selector-parser/dist/util/unesc.js
var require_unesc = __commonJS({
  "node_modules/postcss-selector-parser/dist/util/unesc.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = unesc;
    function gobbleHex(str) {
      var lower = str.toLowerCase();
      var hex = "";
      var spaceTerminated = false;
      for (var i = 0; i < 6 && lower[i] !== void 0; i++) {
        var code = lower.charCodeAt(i);
        var valid = code >= 97 && code <= 102 || code >= 48 && code <= 57;
        spaceTerminated = code === 32;
        if (!valid) {
          break;
        }
        hex += lower[i];
      }
      if (hex.length === 0) {
        return void 0;
      }
      var codePoint = parseInt(hex, 16);
      var isSurrogate = codePoint >= 55296 && codePoint <= 57343;
      if (isSurrogate || codePoint === 0 || codePoint > 1114111) {
        return ["\uFFFD", hex.length + (spaceTerminated ? 1 : 0)];
      }
      return [String.fromCodePoint(codePoint), hex.length + (spaceTerminated ? 1 : 0)];
    }
    var CONTAINS_ESCAPE = /\\/;
    function unesc(str) {
      var needToProcess = CONTAINS_ESCAPE.test(str);
      if (!needToProcess) {
        return str;
      }
      var ret = "";
      for (var i = 0; i < str.length; i++) {
        if (str[i] === "\\") {
          var gobbled = gobbleHex(str.slice(i + 1, i + 7));
          if (gobbled !== void 0) {
            ret += gobbled[0];
            i += gobbled[1];
            continue;
          }
          if (str[i + 1] === "\\") {
            ret += "\\";
            i++;
            continue;
          }
          if (str.length === i + 1) {
            ret += str[i];
          }
          continue;
        }
        ret += str[i];
      }
      return ret;
    }
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/util/getProp.js
var require_getProp = __commonJS({
  "node_modules/postcss-selector-parser/dist/util/getProp.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = getProp;
    function getProp(obj) {
      for (var _len = arguments.length, props = new Array(_len > 1 ? _len - 1 : 0), _key = 1; _key < _len; _key++) {
        props[_key - 1] = arguments[_key];
      }
      while (props.length > 0) {
        var prop = props.shift();
        if (!obj[prop]) {
          return void 0;
        }
        obj = obj[prop];
      }
      return obj;
    }
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/util/ensureObject.js
var require_ensureObject = __commonJS({
  "node_modules/postcss-selector-parser/dist/util/ensureObject.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = ensureObject;
    function ensureObject(obj) {
      for (var _len = arguments.length, props = new Array(_len > 1 ? _len - 1 : 0), _key = 1; _key < _len; _key++) {
        props[_key - 1] = arguments[_key];
      }
      while (props.length > 0) {
        var prop = props.shift();
        if (!obj[prop]) {
          obj[prop] = {};
        }
        obj = obj[prop];
      }
    }
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/util/stripComments.js
var require_stripComments = __commonJS({
  "node_modules/postcss-selector-parser/dist/util/stripComments.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = stripComments;
    function stripComments(str) {
      var s = "";
      var commentStart = str.indexOf("/*");
      var lastEnd = 0;
      while (commentStart >= 0) {
        s = s + str.slice(lastEnd, commentStart);
        var commentEnd = str.indexOf("*/", commentStart + 2);
        if (commentEnd < 0) {
          return s;
        }
        lastEnd = commentEnd + 2;
        commentStart = str.indexOf("/*", lastEnd);
      }
      s = s + str.slice(lastEnd);
      return s;
    }
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/util/index.js
var require_util = __commonJS({
  "node_modules/postcss-selector-parser/dist/util/index.js"(exports) {
    "use strict";
    exports.__esModule = true;
    exports.stripComments = exports.ensureObject = exports.getProp = exports.unesc = void 0;
    var _unesc = _interopRequireDefault(require_unesc());
    exports.unesc = _unesc["default"];
    var _getProp = _interopRequireDefault(require_getProp());
    exports.getProp = _getProp["default"];
    var _ensureObject = _interopRequireDefault(require_ensureObject());
    exports.ensureObject = _ensureObject["default"];
    var _stripComments = _interopRequireDefault(require_stripComments());
    exports.stripComments = _stripComments["default"];
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
  }
});

// node_modules/postcss-selector-parser/dist/selectors/node.js
var require_node = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/node.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = void 0;
    var _util = require_util();
    function _defineProperties(target, props) {
      for (var i = 0; i < props.length; i++) {
        var descriptor = props[i];
        descriptor.enumerable = descriptor.enumerable || false;
        descriptor.configurable = true;
        if ("value" in descriptor) descriptor.writable = true;
        Object.defineProperty(target, descriptor.key, descriptor);
      }
    }
    function _createClass(Constructor, protoProps, staticProps) {
      if (protoProps) _defineProperties(Constructor.prototype, protoProps);
      if (staticProps) _defineProperties(Constructor, staticProps);
      return Constructor;
    }
    var cloneNode = function cloneNode2(obj, parent) {
      if (typeof obj !== "object" || obj === null) {
        return obj;
      }
      var cloned = new obj.constructor();
      for (var i in obj) {
        if (!obj.hasOwnProperty(i)) {
          continue;
        }
        var value = obj[i];
        var type = typeof value;
        if (i === "parent" && type === "object") {
          if (parent) {
            cloned[i] = parent;
          }
        } else if (value instanceof Array) {
          cloned[i] = value.map(function(j) {
            return cloneNode2(j, cloned);
          });
        } else {
          cloned[i] = cloneNode2(value, cloned);
        }
      }
      return cloned;
    };
    var Node = /* @__PURE__ */ function() {
      function Node2(opts) {
        if (opts === void 0) {
          opts = {};
        }
        Object.assign(this, opts);
        this.spaces = this.spaces || {};
        this.spaces.before = this.spaces.before || "";
        this.spaces.after = this.spaces.after || "";
      }
      var _proto = Node2.prototype;
      _proto.remove = function remove() {
        if (this.parent) {
          this.parent.removeChild(this);
        }
        this.parent = void 0;
        return this;
      };
      _proto.replaceWith = function replaceWith() {
        if (this.parent) {
          for (var index in arguments) {
            this.parent.insertBefore(this, arguments[index]);
          }
          this.remove();
        }
        return this;
      };
      _proto.next = function next() {
        return this.parent.at(this.parent.index(this) + 1);
      };
      _proto.prev = function prev() {
        return this.parent.at(this.parent.index(this) - 1);
      };
      _proto.clone = function clone(overrides) {
        if (overrides === void 0) {
          overrides = {};
        }
        var cloned = cloneNode(this);
        for (var name in overrides) {
          cloned[name] = overrides[name];
        }
        return cloned;
      };
      _proto.appendToPropertyAndEscape = function appendToPropertyAndEscape(name, value, valueEscaped) {
        if (!this.raws) {
          this.raws = {};
        }
        var originalValue = this[name];
        var originalEscaped = this.raws[name];
        this[name] = originalValue + value;
        if (originalEscaped || valueEscaped !== value) {
          this.raws[name] = (originalEscaped || originalValue) + valueEscaped;
        } else {
          delete this.raws[name];
        }
      };
      _proto.setPropertyAndEscape = function setPropertyAndEscape(name, value, valueEscaped) {
        if (!this.raws) {
          this.raws = {};
        }
        this[name] = value;
        this.raws[name] = valueEscaped;
      };
      _proto.setPropertyWithoutEscape = function setPropertyWithoutEscape(name, value) {
        this[name] = value;
        if (this.raws) {
          delete this.raws[name];
        }
      };
      _proto.isAtPosition = function isAtPosition(line, column) {
        if (this.source && this.source.start && this.source.end) {
          if (this.source.start.line > line) {
            return false;
          }
          if (this.source.end.line < line) {
            return false;
          }
          if (this.source.start.line === line && this.source.start.column > column) {
            return false;
          }
          if (this.source.end.line === line && this.source.end.column < column) {
            return false;
          }
          return true;
        }
        return void 0;
      };
      _proto.stringifyProperty = function stringifyProperty(name) {
        return this.raws && this.raws[name] || this[name];
      };
      _proto.valueToString = function valueToString() {
        return String(this.stringifyProperty("value"));
      };
      _proto.toString = function toString() {
        return [this.rawSpaceBefore, this.valueToString(), this.rawSpaceAfter].join("");
      };
      _createClass(Node2, [{
        key: "rawSpaceBefore",
        get: function get() {
          var rawSpace = this.raws && this.raws.spaces && this.raws.spaces.before;
          if (rawSpace === void 0) {
            rawSpace = this.spaces && this.spaces.before;
          }
          return rawSpace || "";
        },
        set: function set(raw) {
          (0, _util.ensureObject)(this, "raws", "spaces");
          this.raws.spaces.before = raw;
        }
      }, {
        key: "rawSpaceAfter",
        get: function get() {
          var rawSpace = this.raws && this.raws.spaces && this.raws.spaces.after;
          if (rawSpace === void 0) {
            rawSpace = this.spaces.after;
          }
          return rawSpace || "";
        },
        set: function set(raw) {
          (0, _util.ensureObject)(this, "raws", "spaces");
          this.raws.spaces.after = raw;
        }
      }]);
      return Node2;
    }();
    exports["default"] = Node;
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/types.js
var require_types = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/types.js"(exports) {
    "use strict";
    exports.__esModule = true;
    exports.UNIVERSAL = exports.ATTRIBUTE = exports.CLASS = exports.COMBINATOR = exports.COMMENT = exports.ID = exports.NESTING = exports.PSEUDO = exports.ROOT = exports.SELECTOR = exports.STRING = exports.TAG = void 0;
    var TAG = "tag";
    exports.TAG = TAG;
    var STRING = "string";
    exports.STRING = STRING;
    var SELECTOR = "selector";
    exports.SELECTOR = SELECTOR;
    var ROOT = "root";
    exports.ROOT = ROOT;
    var PSEUDO = "pseudo";
    exports.PSEUDO = PSEUDO;
    var NESTING = "nesting";
    exports.NESTING = NESTING;
    var ID = "id";
    exports.ID = ID;
    var COMMENT = "comment";
    exports.COMMENT = COMMENT;
    var COMBINATOR = "combinator";
    exports.COMBINATOR = COMBINATOR;
    var CLASS = "class";
    exports.CLASS = CLASS;
    var ATTRIBUTE = "attribute";
    exports.ATTRIBUTE = ATTRIBUTE;
    var UNIVERSAL = "universal";
    exports.UNIVERSAL = UNIVERSAL;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/container.js
var require_container = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/container.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = void 0;
    var _node = _interopRequireDefault(require_node());
    var types = _interopRequireWildcard(require_types());
    function _getRequireWildcardCache() {
      if (typeof WeakMap !== "function") return null;
      var cache = /* @__PURE__ */ new WeakMap();
      _getRequireWildcardCache = function _getRequireWildcardCache2() {
        return cache;
      };
      return cache;
    }
    function _interopRequireWildcard(obj) {
      if (obj && obj.__esModule) {
        return obj;
      }
      if (obj === null || typeof obj !== "object" && typeof obj !== "function") {
        return { "default": obj };
      }
      var cache = _getRequireWildcardCache();
      if (cache && cache.has(obj)) {
        return cache.get(obj);
      }
      var newObj = {};
      var hasPropertyDescriptor = Object.defineProperty && Object.getOwnPropertyDescriptor;
      for (var key in obj) {
        if (Object.prototype.hasOwnProperty.call(obj, key)) {
          var desc = hasPropertyDescriptor ? Object.getOwnPropertyDescriptor(obj, key) : null;
          if (desc && (desc.get || desc.set)) {
            Object.defineProperty(newObj, key, desc);
          } else {
            newObj[key] = obj[key];
          }
        }
      }
      newObj["default"] = obj;
      if (cache) {
        cache.set(obj, newObj);
      }
      return newObj;
    }
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _createForOfIteratorHelperLoose(o, allowArrayLike) {
      var it;
      if (typeof Symbol === "undefined" || o[Symbol.iterator] == null) {
        if (Array.isArray(o) || (it = _unsupportedIterableToArray(o)) || allowArrayLike && o && typeof o.length === "number") {
          if (it) o = it;
          var i = 0;
          return function() {
            if (i >= o.length) return { done: true };
            return { done: false, value: o[i++] };
          };
        }
        throw new TypeError("Invalid attempt to iterate non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method.");
      }
      it = o[Symbol.iterator]();
      return it.next.bind(it);
    }
    function _unsupportedIterableToArray(o, minLen) {
      if (!o) return;
      if (typeof o === "string") return _arrayLikeToArray(o, minLen);
      var n = Object.prototype.toString.call(o).slice(8, -1);
      if (n === "Object" && o.constructor) n = o.constructor.name;
      if (n === "Map" || n === "Set") return Array.from(o);
      if (n === "Arguments" || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(n)) return _arrayLikeToArray(o, minLen);
    }
    function _arrayLikeToArray(arr, len) {
      if (len == null || len > arr.length) len = arr.length;
      for (var i = 0, arr2 = new Array(len); i < len; i++) {
        arr2[i] = arr[i];
      }
      return arr2;
    }
    function _defineProperties(target, props) {
      for (var i = 0; i < props.length; i++) {
        var descriptor = props[i];
        descriptor.enumerable = descriptor.enumerable || false;
        descriptor.configurable = true;
        if ("value" in descriptor) descriptor.writable = true;
        Object.defineProperty(target, descriptor.key, descriptor);
      }
    }
    function _createClass(Constructor, protoProps, staticProps) {
      if (protoProps) _defineProperties(Constructor.prototype, protoProps);
      if (staticProps) _defineProperties(Constructor, staticProps);
      return Constructor;
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Container = /* @__PURE__ */ function(_Node) {
      _inheritsLoose(Container2, _Node);
      function Container2(opts) {
        var _this;
        _this = _Node.call(this, opts) || this;
        if (!_this.nodes) {
          _this.nodes = [];
        }
        return _this;
      }
      var _proto = Container2.prototype;
      _proto.append = function append(selector) {
        selector.parent = this;
        this.nodes.push(selector);
        return this;
      };
      _proto.prepend = function prepend(selector) {
        selector.parent = this;
        this.nodes.unshift(selector);
        return this;
      };
      _proto.at = function at(index) {
        return this.nodes[index];
      };
      _proto.index = function index(child) {
        if (typeof child === "number") {
          return child;
        }
        return this.nodes.indexOf(child);
      };
      _proto.removeChild = function removeChild(child) {
        child = this.index(child);
        this.at(child).parent = void 0;
        this.nodes.splice(child, 1);
        var index;
        for (var id in this.indexes) {
          index = this.indexes[id];
          if (index >= child) {
            this.indexes[id] = index - 1;
          }
        }
        return this;
      };
      _proto.removeAll = function removeAll() {
        for (var _iterator = _createForOfIteratorHelperLoose(this.nodes), _step; !(_step = _iterator()).done; ) {
          var node = _step.value;
          node.parent = void 0;
        }
        this.nodes = [];
        return this;
      };
      _proto.empty = function empty() {
        return this.removeAll();
      };
      _proto.insertAfter = function insertAfter(oldNode, newNode) {
        newNode.parent = this;
        var oldIndex = this.index(oldNode);
        this.nodes.splice(oldIndex + 1, 0, newNode);
        newNode.parent = this;
        var index;
        for (var id in this.indexes) {
          index = this.indexes[id];
          if (oldIndex <= index) {
            this.indexes[id] = index + 1;
          }
        }
        return this;
      };
      _proto.insertBefore = function insertBefore(oldNode, newNode) {
        newNode.parent = this;
        var oldIndex = this.index(oldNode);
        this.nodes.splice(oldIndex, 0, newNode);
        newNode.parent = this;
        var index;
        for (var id in this.indexes) {
          index = this.indexes[id];
          if (index <= oldIndex) {
            this.indexes[id] = index + 1;
          }
        }
        return this;
      };
      _proto._findChildAtPosition = function _findChildAtPosition(line, col) {
        var found = void 0;
        this.each(function(node) {
          if (node.atPosition) {
            var foundChild = node.atPosition(line, col);
            if (foundChild) {
              found = foundChild;
              return false;
            }
          } else if (node.isAtPosition(line, col)) {
            found = node;
            return false;
          }
        });
        return found;
      };
      _proto.atPosition = function atPosition(line, col) {
        if (this.isAtPosition(line, col)) {
          return this._findChildAtPosition(line, col) || this;
        } else {
          return void 0;
        }
      };
      _proto._inferEndPosition = function _inferEndPosition() {
        if (this.last && this.last.source && this.last.source.end) {
          this.source = this.source || {};
          this.source.end = this.source.end || {};
          Object.assign(this.source.end, this.last.source.end);
        }
      };
      _proto.each = function each(callback) {
        if (!this.lastEach) {
          this.lastEach = 0;
        }
        if (!this.indexes) {
          this.indexes = {};
        }
        this.lastEach++;
        var id = this.lastEach;
        this.indexes[id] = 0;
        if (!this.length) {
          return void 0;
        }
        var index, result;
        while (this.indexes[id] < this.length) {
          index = this.indexes[id];
          result = callback(this.at(index), index);
          if (result === false) {
            break;
          }
          this.indexes[id] += 1;
        }
        delete this.indexes[id];
        if (result === false) {
          return false;
        }
      };
      _proto.walk = function walk(callback) {
        return this.each(function(node, i) {
          var result = callback(node, i);
          if (result !== false && node.length) {
            result = node.walk(callback);
          }
          if (result === false) {
            return false;
          }
        });
      };
      _proto.walkAttributes = function walkAttributes(callback) {
        var _this2 = this;
        return this.walk(function(selector) {
          if (selector.type === types.ATTRIBUTE) {
            return callback.call(_this2, selector);
          }
        });
      };
      _proto.walkClasses = function walkClasses(callback) {
        var _this3 = this;
        return this.walk(function(selector) {
          if (selector.type === types.CLASS) {
            return callback.call(_this3, selector);
          }
        });
      };
      _proto.walkCombinators = function walkCombinators(callback) {
        var _this4 = this;
        return this.walk(function(selector) {
          if (selector.type === types.COMBINATOR) {
            return callback.call(_this4, selector);
          }
        });
      };
      _proto.walkComments = function walkComments(callback) {
        var _this5 = this;
        return this.walk(function(selector) {
          if (selector.type === types.COMMENT) {
            return callback.call(_this5, selector);
          }
        });
      };
      _proto.walkIds = function walkIds(callback) {
        var _this6 = this;
        return this.walk(function(selector) {
          if (selector.type === types.ID) {
            return callback.call(_this6, selector);
          }
        });
      };
      _proto.walkNesting = function walkNesting(callback) {
        var _this7 = this;
        return this.walk(function(selector) {
          if (selector.type === types.NESTING) {
            return callback.call(_this7, selector);
          }
        });
      };
      _proto.walkPseudos = function walkPseudos(callback) {
        var _this8 = this;
        return this.walk(function(selector) {
          if (selector.type === types.PSEUDO) {
            return callback.call(_this8, selector);
          }
        });
      };
      _proto.walkTags = function walkTags(callback) {
        var _this9 = this;
        return this.walk(function(selector) {
          if (selector.type === types.TAG) {
            return callback.call(_this9, selector);
          }
        });
      };
      _proto.walkUniversals = function walkUniversals(callback) {
        var _this10 = this;
        return this.walk(function(selector) {
          if (selector.type === types.UNIVERSAL) {
            return callback.call(_this10, selector);
          }
        });
      };
      _proto.split = function split(callback) {
        var _this11 = this;
        var current = [];
        return this.reduce(function(memo, node, index) {
          var split2 = callback.call(_this11, node);
          current.push(node);
          if (split2) {
            memo.push(current);
            current = [];
          } else if (index === _this11.length - 1) {
            memo.push(current);
          }
          return memo;
        }, []);
      };
      _proto.map = function map(callback) {
        return this.nodes.map(callback);
      };
      _proto.reduce = function reduce(callback, memo) {
        return this.nodes.reduce(callback, memo);
      };
      _proto.every = function every(callback) {
        return this.nodes.every(callback);
      };
      _proto.some = function some(callback) {
        return this.nodes.some(callback);
      };
      _proto.filter = function filter(callback) {
        return this.nodes.filter(callback);
      };
      _proto.sort = function sort(callback) {
        return this.nodes.sort(callback);
      };
      _proto.toString = function toString() {
        return this.map(String).join("");
      };
      _createClass(Container2, [{
        key: "first",
        get: function get() {
          return this.at(0);
        }
      }, {
        key: "last",
        get: function get() {
          return this.at(this.length - 1);
        }
      }, {
        key: "length",
        get: function get() {
          return this.nodes.length;
        }
      }]);
      return Container2;
    }(_node["default"]);
    exports["default"] = Container;
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/root.js
var require_root = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/root.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = void 0;
    var _container = _interopRequireDefault(require_container());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _defineProperties(target, props) {
      for (var i = 0; i < props.length; i++) {
        var descriptor = props[i];
        descriptor.enumerable = descriptor.enumerable || false;
        descriptor.configurable = true;
        if ("value" in descriptor) descriptor.writable = true;
        Object.defineProperty(target, descriptor.key, descriptor);
      }
    }
    function _createClass(Constructor, protoProps, staticProps) {
      if (protoProps) _defineProperties(Constructor.prototype, protoProps);
      if (staticProps) _defineProperties(Constructor, staticProps);
      return Constructor;
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Root = /* @__PURE__ */ function(_Container) {
      _inheritsLoose(Root2, _Container);
      function Root2(opts) {
        var _this;
        _this = _Container.call(this, opts) || this;
        _this.type = _types.ROOT;
        return _this;
      }
      var _proto = Root2.prototype;
      _proto.toString = function toString() {
        var str = this.reduce(function(memo, selector) {
          memo.push(String(selector));
          return memo;
        }, []).join(",");
        return this.trailingComma ? str + "," : str;
      };
      _proto.error = function error(message, options) {
        if (this._error) {
          return this._error(message, options);
        } else {
          return new Error(message);
        }
      };
      _createClass(Root2, [{
        key: "errorGenerator",
        set: function set(handler) {
          this._error = handler;
        }
      }]);
      return Root2;
    }(_container["default"]);
    exports["default"] = Root;
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/selector.js
var require_selector = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/selector.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = void 0;
    var _container = _interopRequireDefault(require_container());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Selector = /* @__PURE__ */ function(_Container) {
      _inheritsLoose(Selector2, _Container);
      function Selector2(opts) {
        var _this;
        _this = _Container.call(this, opts) || this;
        _this.type = _types.SELECTOR;
        return _this;
      }
      return Selector2;
    }(_container["default"]);
    exports["default"] = Selector;
    module.exports = exports.default;
  }
});

// node_modules/cssesc/cssesc.js
var require_cssesc = __commonJS({
  "node_modules/cssesc/cssesc.js"(exports, module) {
    "use strict";
    var object = {};
    var hasOwnProperty = object.hasOwnProperty;
    var merge = function merge2(options, defaults) {
      if (!options) {
        return defaults;
      }
      var result = {};
      for (var key in defaults) {
        result[key] = hasOwnProperty.call(options, key) ? options[key] : defaults[key];
      }
      return result;
    };
    var regexAnySingleEscape = /[ -,\.\/:-@\[-\^`\{-~]/;
    var regexSingleEscape = /[ -,\.\/:-@\[\]\^`\{-~]/;
    var regexExcessiveSpaces = /(^|\\+)?(\\[A-F0-9]{1,6})\x20(?![a-fA-F0-9\x20])/g;
    var cssesc = function cssesc2(string, options) {
      options = merge(options, cssesc2.options);
      if (options.quotes != "single" && options.quotes != "double") {
        options.quotes = "single";
      }
      var quote = options.quotes == "double" ? '"' : "'";
      var isIdentifier = options.isIdentifier;
      var firstChar = string.charAt(0);
      var output = "";
      var counter = 0;
      var length = string.length;
      while (counter < length) {
        var character = string.charAt(counter++);
        var codePoint = character.charCodeAt();
        var value = void 0;
        if (codePoint < 32 || codePoint > 126) {
          if (codePoint >= 55296 && codePoint <= 56319 && counter < length) {
            var extra = string.charCodeAt(counter++);
            if ((extra & 64512) == 56320) {
              codePoint = ((codePoint & 1023) << 10) + (extra & 1023) + 65536;
            } else {
              counter--;
            }
          }
          value = "\\" + codePoint.toString(16).toUpperCase() + " ";
        } else {
          if (options.escapeEverything) {
            if (regexAnySingleEscape.test(character)) {
              value = "\\" + character;
            } else {
              value = "\\" + codePoint.toString(16).toUpperCase() + " ";
            }
          } else if (/[\t\n\f\r\x0B]/.test(character)) {
            value = "\\" + codePoint.toString(16).toUpperCase() + " ";
          } else if (character == "\\" || !isIdentifier && (character == '"' && quote == character || character == "'" && quote == character) || isIdentifier && regexSingleEscape.test(character)) {
            value = "\\" + character;
          } else {
            value = character;
          }
        }
        output += value;
      }
      if (isIdentifier) {
        if (/^-[-\d]/.test(output)) {
          output = "\\-" + output.slice(1);
        } else if (/\d/.test(firstChar)) {
          output = "\\3" + firstChar + " " + output.slice(1);
        }
      }
      output = output.replace(regexExcessiveSpaces, function($0, $1, $2) {
        if ($1 && $1.length % 2) {
          return $0;
        }
        return ($1 || "") + $2;
      });
      if (!isIdentifier && options.wrap) {
        return quote + output + quote;
      }
      return output;
    };
    cssesc.options = {
      "escapeEverything": false,
      "isIdentifier": false,
      "quotes": "single",
      "wrap": false
    };
    cssesc.version = "3.0.0";
    module.exports = cssesc;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/className.js
var require_className = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/className.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = void 0;
    var _cssesc = _interopRequireDefault(require_cssesc());
    var _util = require_util();
    var _node = _interopRequireDefault(require_node());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _defineProperties(target, props) {
      for (var i = 0; i < props.length; i++) {
        var descriptor = props[i];
        descriptor.enumerable = descriptor.enumerable || false;
        descriptor.configurable = true;
        if ("value" in descriptor) descriptor.writable = true;
        Object.defineProperty(target, descriptor.key, descriptor);
      }
    }
    function _createClass(Constructor, protoProps, staticProps) {
      if (protoProps) _defineProperties(Constructor.prototype, protoProps);
      if (staticProps) _defineProperties(Constructor, staticProps);
      return Constructor;
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var ClassName = /* @__PURE__ */ function(_Node) {
      _inheritsLoose(ClassName2, _Node);
      function ClassName2(opts) {
        var _this;
        _this = _Node.call(this, opts) || this;
        _this.type = _types.CLASS;
        _this._constructed = true;
        return _this;
      }
      var _proto = ClassName2.prototype;
      _proto.valueToString = function valueToString() {
        return "." + _Node.prototype.valueToString.call(this);
      };
      _createClass(ClassName2, [{
        key: "value",
        get: function get() {
          return this._value;
        },
        set: function set(v) {
          if (this._constructed) {
            var escaped = (0, _cssesc["default"])(v, {
              isIdentifier: true
            });
            if (escaped !== v) {
              (0, _util.ensureObject)(this, "raws");
              this.raws.value = escaped;
            } else if (this.raws) {
              delete this.raws.value;
            }
          }
          this._value = v;
        }
      }]);
      return ClassName2;
    }(_node["default"]);
    exports["default"] = ClassName;
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/comment.js
var require_comment = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/comment.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = void 0;
    var _node = _interopRequireDefault(require_node());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Comment = /* @__PURE__ */ function(_Node) {
      _inheritsLoose(Comment2, _Node);
      function Comment2(opts) {
        var _this;
        _this = _Node.call(this, opts) || this;
        _this.type = _types.COMMENT;
        return _this;
      }
      return Comment2;
    }(_node["default"]);
    exports["default"] = Comment;
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/id.js
var require_id = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/id.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = void 0;
    var _node = _interopRequireDefault(require_node());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var ID = /* @__PURE__ */ function(_Node) {
      _inheritsLoose(ID2, _Node);
      function ID2(opts) {
        var _this;
        _this = _Node.call(this, opts) || this;
        _this.type = _types.ID;
        return _this;
      }
      var _proto = ID2.prototype;
      _proto.valueToString = function valueToString() {
        return "#" + _Node.prototype.valueToString.call(this);
      };
      return ID2;
    }(_node["default"]);
    exports["default"] = ID;
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/namespace.js
var require_namespace = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/namespace.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = void 0;
    var _cssesc = _interopRequireDefault(require_cssesc());
    var _util = require_util();
    var _node = _interopRequireDefault(require_node());
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _defineProperties(target, props) {
      for (var i = 0; i < props.length; i++) {
        var descriptor = props[i];
        descriptor.enumerable = descriptor.enumerable || false;
        descriptor.configurable = true;
        if ("value" in descriptor) descriptor.writable = true;
        Object.defineProperty(target, descriptor.key, descriptor);
      }
    }
    function _createClass(Constructor, protoProps, staticProps) {
      if (protoProps) _defineProperties(Constructor.prototype, protoProps);
      if (staticProps) _defineProperties(Constructor, staticProps);
      return Constructor;
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Namespace = /* @__PURE__ */ function(_Node) {
      _inheritsLoose(Namespace2, _Node);
      function Namespace2() {
        return _Node.apply(this, arguments) || this;
      }
      var _proto = Namespace2.prototype;
      _proto.qualifiedName = function qualifiedName(value) {
        if (this.namespace) {
          return this.namespaceString + "|" + value;
        } else {
          return value;
        }
      };
      _proto.valueToString = function valueToString() {
        return this.qualifiedName(_Node.prototype.valueToString.call(this));
      };
      _createClass(Namespace2, [{
        key: "namespace",
        get: function get() {
          return this._namespace;
        },
        set: function set(namespace) {
          if (namespace === true || namespace === "*" || namespace === "&") {
            this._namespace = namespace;
            if (this.raws) {
              delete this.raws.namespace;
            }
            return;
          }
          var escaped = (0, _cssesc["default"])(namespace, {
            isIdentifier: true
          });
          this._namespace = namespace;
          if (escaped !== namespace) {
            (0, _util.ensureObject)(this, "raws");
            this.raws.namespace = escaped;
          } else if (this.raws) {
            delete this.raws.namespace;
          }
        }
      }, {
        key: "ns",
        get: function get() {
          return this._namespace;
        },
        set: function set(namespace) {
          this.namespace = namespace;
        }
      }, {
        key: "namespaceString",
        get: function get() {
          if (this.namespace) {
            var ns = this.stringifyProperty("namespace");
            if (ns === true) {
              return "";
            } else {
              return ns;
            }
          } else {
            return "";
          }
        }
      }]);
      return Namespace2;
    }(_node["default"]);
    exports["default"] = Namespace;
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/tag.js
var require_tag = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/tag.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = void 0;
    var _namespace = _interopRequireDefault(require_namespace());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Tag = /* @__PURE__ */ function(_Namespace) {
      _inheritsLoose(Tag2, _Namespace);
      function Tag2(opts) {
        var _this;
        _this = _Namespace.call(this, opts) || this;
        _this.type = _types.TAG;
        return _this;
      }
      return Tag2;
    }(_namespace["default"]);
    exports["default"] = Tag;
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/string.js
var require_string = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/string.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = void 0;
    var _node = _interopRequireDefault(require_node());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var String2 = /* @__PURE__ */ function(_Node) {
      _inheritsLoose(String3, _Node);
      function String3(opts) {
        var _this;
        _this = _Node.call(this, opts) || this;
        _this.type = _types.STRING;
        return _this;
      }
      return String3;
    }(_node["default"]);
    exports["default"] = String2;
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/pseudo.js
var require_pseudo = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/pseudo.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = void 0;
    var _container = _interopRequireDefault(require_container());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Pseudo = /* @__PURE__ */ function(_Container) {
      _inheritsLoose(Pseudo2, _Container);
      function Pseudo2(opts) {
        var _this;
        _this = _Container.call(this, opts) || this;
        _this.type = _types.PSEUDO;
        return _this;
      }
      var _proto = Pseudo2.prototype;
      _proto.toString = function toString() {
        var params = this.length ? "(" + this.map(String).join(",") + ")" : "";
        return [this.rawSpaceBefore, this.stringifyProperty("value"), params, this.rawSpaceAfter].join("");
      };
      return Pseudo2;
    }(_container["default"]);
    exports["default"] = Pseudo;
    module.exports = exports.default;
  }
});

// node_modules/util-deprecate/browser.js
var require_browser = __commonJS({
  "node_modules/util-deprecate/browser.js"(exports, module) {
    module.exports = deprecate;
    function deprecate(fn, msg) {
      if (config("noDeprecation")) {
        return fn;
      }
      var warned = false;
      function deprecated() {
        if (!warned) {
          if (config("throwDeprecation")) {
            throw new Error(msg);
          } else if (config("traceDeprecation")) {
            console.trace(msg);
          } else {
            console.warn(msg);
          }
          warned = true;
        }
        return fn.apply(this, arguments);
      }
      return deprecated;
    }
    function config(name) {
      try {
        if (!global.localStorage) return false;
      } catch (_) {
        return false;
      }
      var val = global.localStorage[name];
      if (null == val) return false;
      return String(val).toLowerCase() === "true";
    }
  }
});

// node_modules/postcss-selector-parser/dist/selectors/attribute.js
var require_attribute = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/attribute.js"(exports) {
    "use strict";
    exports.__esModule = true;
    exports.unescapeValue = unescapeValue;
    exports["default"] = void 0;
    var _cssesc = _interopRequireDefault(require_cssesc());
    var _unesc = _interopRequireDefault(require_unesc());
    var _namespace = _interopRequireDefault(require_namespace());
    var _types = require_types();
    var _CSSESC_QUOTE_OPTIONS;
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _defineProperties(target, props) {
      for (var i = 0; i < props.length; i++) {
        var descriptor = props[i];
        descriptor.enumerable = descriptor.enumerable || false;
        descriptor.configurable = true;
        if ("value" in descriptor) descriptor.writable = true;
        Object.defineProperty(target, descriptor.key, descriptor);
      }
    }
    function _createClass(Constructor, protoProps, staticProps) {
      if (protoProps) _defineProperties(Constructor.prototype, protoProps);
      if (staticProps) _defineProperties(Constructor, staticProps);
      return Constructor;
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var deprecate = require_browser();
    var WRAPPED_IN_QUOTES = /^('|")([^]*)\1$/;
    var warnOfDeprecatedValueAssignment = deprecate(function() {
    }, "Assigning an attribute a value containing characters that might need to be escaped is deprecated. Call attribute.setValue() instead.");
    var warnOfDeprecatedQuotedAssignment = deprecate(function() {
    }, "Assigning attr.quoted is deprecated and has no effect. Assign to attr.quoteMark instead.");
    var warnOfDeprecatedConstructor = deprecate(function() {
    }, "Constructing an Attribute selector with a value without specifying quoteMark is deprecated. Note: The value should be unescaped now.");
    function unescapeValue(value) {
      var deprecatedUsage = false;
      var quoteMark = null;
      var unescaped = value;
      var m = unescaped.match(WRAPPED_IN_QUOTES);
      if (m) {
        quoteMark = m[1];
        unescaped = m[2];
      }
      unescaped = (0, _unesc["default"])(unescaped);
      if (unescaped !== value) {
        deprecatedUsage = true;
      }
      return {
        deprecatedUsage,
        unescaped,
        quoteMark
      };
    }
    function handleDeprecatedContructorOpts(opts) {
      if (opts.quoteMark !== void 0) {
        return opts;
      }
      if (opts.value === void 0) {
        return opts;
      }
      warnOfDeprecatedConstructor();
      var _unescapeValue = unescapeValue(opts.value), quoteMark = _unescapeValue.quoteMark, unescaped = _unescapeValue.unescaped;
      if (!opts.raws) {
        opts.raws = {};
      }
      if (opts.raws.value === void 0) {
        opts.raws.value = opts.value;
      }
      opts.value = unescaped;
      opts.quoteMark = quoteMark;
      return opts;
    }
    var Attribute = /* @__PURE__ */ function(_Namespace) {
      _inheritsLoose(Attribute2, _Namespace);
      function Attribute2(opts) {
        var _this;
        if (opts === void 0) {
          opts = {};
        }
        _this = _Namespace.call(this, handleDeprecatedContructorOpts(opts)) || this;
        _this.type = _types.ATTRIBUTE;
        _this.raws = _this.raws || {};
        Object.defineProperty(_this.raws, "unquoted", {
          get: deprecate(function() {
            return _this.value;
          }, "attr.raws.unquoted is deprecated. Call attr.value instead."),
          set: deprecate(function() {
            return _this.value;
          }, "Setting attr.raws.unquoted is deprecated and has no effect. attr.value is unescaped by default now.")
        });
        _this._constructed = true;
        return _this;
      }
      var _proto = Attribute2.prototype;
      _proto.getQuotedValue = function getQuotedValue(options) {
        if (options === void 0) {
          options = {};
        }
        var quoteMark = this._determineQuoteMark(options);
        var cssescopts = CSSESC_QUOTE_OPTIONS[quoteMark];
        var escaped = (0, _cssesc["default"])(this._value, cssescopts);
        return escaped;
      };
      _proto._determineQuoteMark = function _determineQuoteMark(options) {
        return options.smart ? this.smartQuoteMark(options) : this.preferredQuoteMark(options);
      };
      _proto.setValue = function setValue(value, options) {
        if (options === void 0) {
          options = {};
        }
        this._value = value;
        this._quoteMark = this._determineQuoteMark(options);
        this._syncRawValue();
      };
      _proto.smartQuoteMark = function smartQuoteMark(options) {
        var v = this.value;
        var numSingleQuotes = v.replace(/[^']/g, "").length;
        var numDoubleQuotes = v.replace(/[^"]/g, "").length;
        if (numSingleQuotes + numDoubleQuotes === 0) {
          var escaped = (0, _cssesc["default"])(v, {
            isIdentifier: true
          });
          if (escaped === v) {
            return Attribute2.NO_QUOTE;
          } else {
            var pref = this.preferredQuoteMark(options);
            if (pref === Attribute2.NO_QUOTE) {
              var quote = this.quoteMark || options.quoteMark || Attribute2.DOUBLE_QUOTE;
              var opts = CSSESC_QUOTE_OPTIONS[quote];
              var quoteValue = (0, _cssesc["default"])(v, opts);
              if (quoteValue.length < escaped.length) {
                return quote;
              }
            }
            return pref;
          }
        } else if (numDoubleQuotes === numSingleQuotes) {
          return this.preferredQuoteMark(options);
        } else if (numDoubleQuotes < numSingleQuotes) {
          return Attribute2.DOUBLE_QUOTE;
        } else {
          return Attribute2.SINGLE_QUOTE;
        }
      };
      _proto.preferredQuoteMark = function preferredQuoteMark(options) {
        var quoteMark = options.preferCurrentQuoteMark ? this.quoteMark : options.quoteMark;
        if (quoteMark === void 0) {
          quoteMark = options.preferCurrentQuoteMark ? options.quoteMark : this.quoteMark;
        }
        if (quoteMark === void 0) {
          quoteMark = Attribute2.DOUBLE_QUOTE;
        }
        return quoteMark;
      };
      _proto._syncRawValue = function _syncRawValue() {
        var rawValue = (0, _cssesc["default"])(this._value, CSSESC_QUOTE_OPTIONS[this.quoteMark]);
        if (rawValue === this._value) {
          if (this.raws) {
            delete this.raws.value;
          }
        } else {
          this.raws.value = rawValue;
        }
      };
      _proto._handleEscapes = function _handleEscapes(prop, value) {
        if (this._constructed) {
          var escaped = (0, _cssesc["default"])(value, {
            isIdentifier: true
          });
          if (escaped !== value) {
            this.raws[prop] = escaped;
          } else {
            delete this.raws[prop];
          }
        }
      };
      _proto._spacesFor = function _spacesFor(name) {
        var attrSpaces = {
          before: "",
          after: ""
        };
        var spaces = this.spaces[name] || {};
        var rawSpaces = this.raws.spaces && this.raws.spaces[name] || {};
        return Object.assign(attrSpaces, spaces, rawSpaces);
      };
      _proto._stringFor = function _stringFor(name, spaceName, concat) {
        if (spaceName === void 0) {
          spaceName = name;
        }
        if (concat === void 0) {
          concat = defaultAttrConcat;
        }
        var attrSpaces = this._spacesFor(spaceName);
        return concat(this.stringifyProperty(name), attrSpaces);
      };
      _proto.offsetOf = function offsetOf(name) {
        var count = 1;
        var attributeSpaces = this._spacesFor("attribute");
        count += attributeSpaces.before.length;
        if (name === "namespace" || name === "ns") {
          return this.namespace ? count : -1;
        }
        if (name === "attributeNS") {
          return count;
        }
        count += this.namespaceString.length;
        if (this.namespace) {
          count += 1;
        }
        if (name === "attribute") {
          return count;
        }
        count += this.stringifyProperty("attribute").length;
        count += attributeSpaces.after.length;
        var operatorSpaces = this._spacesFor("operator");
        count += operatorSpaces.before.length;
        var operator = this.stringifyProperty("operator");
        if (name === "operator") {
          return operator ? count : -1;
        }
        count += operator.length;
        count += operatorSpaces.after.length;
        var valueSpaces = this._spacesFor("value");
        count += valueSpaces.before.length;
        var value = this.stringifyProperty("value");
        if (name === "value") {
          return value ? count : -1;
        }
        count += value.length;
        count += valueSpaces.after.length;
        var insensitiveSpaces = this._spacesFor("insensitive");
        count += insensitiveSpaces.before.length;
        if (name === "insensitive") {
          return this.insensitive ? count : -1;
        }
        return -1;
      };
      _proto.toString = function toString() {
        var _this2 = this;
        var selector = [this.rawSpaceBefore, "["];
        selector.push(this._stringFor("qualifiedAttribute", "attribute"));
        if (this.operator && (this.value || this.value === "")) {
          selector.push(this._stringFor("operator"));
          selector.push(this._stringFor("value"));
          selector.push(this._stringFor("insensitiveFlag", "insensitive", function(attrValue, attrSpaces) {
            if (attrValue.length > 0 && !_this2.quoted && attrSpaces.before.length === 0 && !(_this2.spaces.value && _this2.spaces.value.after)) {
              attrSpaces.before = " ";
            }
            return defaultAttrConcat(attrValue, attrSpaces);
          }));
        }
        selector.push("]");
        selector.push(this.rawSpaceAfter);
        return selector.join("");
      };
      _createClass(Attribute2, [{
        key: "quoted",
        get: function get() {
          var qm = this.quoteMark;
          return qm === "'" || qm === '"';
        },
        set: function set(value) {
          warnOfDeprecatedQuotedAssignment();
        }
        /**
         * returns a single (`'`) or double (`"`) quote character if the value is quoted.
         * returns `null` if the value is not quoted.
         * returns `undefined` if the quotation state is unknown (this can happen when
         * the attribute is constructed without specifying a quote mark.)
         */
      }, {
        key: "quoteMark",
        get: function get() {
          return this._quoteMark;
        },
        set: function set(quoteMark) {
          if (!this._constructed) {
            this._quoteMark = quoteMark;
            return;
          }
          if (this._quoteMark !== quoteMark) {
            this._quoteMark = quoteMark;
            this._syncRawValue();
          }
        }
      }, {
        key: "qualifiedAttribute",
        get: function get() {
          return this.qualifiedName(this.raws.attribute || this.attribute);
        }
      }, {
        key: "insensitiveFlag",
        get: function get() {
          return this.insensitive ? "i" : "";
        }
      }, {
        key: "value",
        get: function get() {
          return this._value;
        },
        set: function set(v) {
          if (this._constructed) {
            var _unescapeValue2 = unescapeValue(v), deprecatedUsage = _unescapeValue2.deprecatedUsage, unescaped = _unescapeValue2.unescaped, quoteMark = _unescapeValue2.quoteMark;
            if (deprecatedUsage) {
              warnOfDeprecatedValueAssignment();
            }
            if (unescaped === this._value && quoteMark === this._quoteMark) {
              return;
            }
            this._value = unescaped;
            this._quoteMark = quoteMark;
            this._syncRawValue();
          } else {
            this._value = v;
          }
        }
      }, {
        key: "attribute",
        get: function get() {
          return this._attribute;
        },
        set: function set(name) {
          this._handleEscapes("attribute", name);
          this._attribute = name;
        }
      }]);
      return Attribute2;
    }(_namespace["default"]);
    exports["default"] = Attribute;
    Attribute.NO_QUOTE = null;
    Attribute.SINGLE_QUOTE = "'";
    Attribute.DOUBLE_QUOTE = '"';
    var CSSESC_QUOTE_OPTIONS = (_CSSESC_QUOTE_OPTIONS = {
      "'": {
        quotes: "single",
        wrap: true
      },
      '"': {
        quotes: "double",
        wrap: true
      }
    }, _CSSESC_QUOTE_OPTIONS[null] = {
      isIdentifier: true
    }, _CSSESC_QUOTE_OPTIONS);
    function defaultAttrConcat(attrValue, attrSpaces) {
      return "" + attrSpaces.before + attrValue + attrSpaces.after;
    }
  }
});

// node_modules/postcss-selector-parser/dist/selectors/universal.js
var require_universal = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/universal.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = void 0;
    var _namespace = _interopRequireDefault(require_namespace());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Universal = /* @__PURE__ */ function(_Namespace) {
      _inheritsLoose(Universal2, _Namespace);
      function Universal2(opts) {
        var _this;
        _this = _Namespace.call(this, opts) || this;
        _this.type = _types.UNIVERSAL;
        _this.value = "*";
        return _this;
      }
      return Universal2;
    }(_namespace["default"]);
    exports["default"] = Universal;
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/combinator.js
var require_combinator = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/combinator.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = void 0;
    var _node = _interopRequireDefault(require_node());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Combinator = /* @__PURE__ */ function(_Node) {
      _inheritsLoose(Combinator2, _Node);
      function Combinator2(opts) {
        var _this;
        _this = _Node.call(this, opts) || this;
        _this.type = _types.COMBINATOR;
        return _this;
      }
      return Combinator2;
    }(_node["default"]);
    exports["default"] = Combinator;
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/nesting.js
var require_nesting = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/nesting.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = void 0;
    var _node = _interopRequireDefault(require_node());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Nesting = /* @__PURE__ */ function(_Node) {
      _inheritsLoose(Nesting2, _Node);
      function Nesting2(opts) {
        var _this;
        _this = _Node.call(this, opts) || this;
        _this.type = _types.NESTING;
        _this.value = "&";
        return _this;
      }
      return Nesting2;
    }(_node["default"]);
    exports["default"] = Nesting;
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/sortAscending.js
var require_sortAscending = __commonJS({
  "node_modules/postcss-selector-parser/dist/sortAscending.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = sortAscending;
    function sortAscending(list) {
      return list.sort(function(a, b) {
        return a - b;
      });
    }
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/tokenTypes.js
var require_tokenTypes = __commonJS({
  "node_modules/postcss-selector-parser/dist/tokenTypes.js"(exports) {
    "use strict";
    exports.__esModule = true;
    exports.combinator = exports.word = exports.comment = exports.str = exports.tab = exports.newline = exports.feed = exports.cr = exports.backslash = exports.bang = exports.slash = exports.doubleQuote = exports.singleQuote = exports.space = exports.greaterThan = exports.pipe = exports.equals = exports.plus = exports.caret = exports.tilde = exports.dollar = exports.closeSquare = exports.openSquare = exports.closeParenthesis = exports.openParenthesis = exports.semicolon = exports.colon = exports.comma = exports.at = exports.asterisk = exports.ampersand = void 0;
    var ampersand = 38;
    exports.ampersand = ampersand;
    var asterisk = 42;
    exports.asterisk = asterisk;
    var at = 64;
    exports.at = at;
    var comma = 44;
    exports.comma = comma;
    var colon = 58;
    exports.colon = colon;
    var semicolon = 59;
    exports.semicolon = semicolon;
    var openParenthesis = 40;
    exports.openParenthesis = openParenthesis;
    var closeParenthesis = 41;
    exports.closeParenthesis = closeParenthesis;
    var openSquare = 91;
    exports.openSquare = openSquare;
    var closeSquare = 93;
    exports.closeSquare = closeSquare;
    var dollar = 36;
    exports.dollar = dollar;
    var tilde = 126;
    exports.tilde = tilde;
    var caret = 94;
    exports.caret = caret;
    var plus = 43;
    exports.plus = plus;
    var equals = 61;
    exports.equals = equals;
    var pipe = 124;
    exports.pipe = pipe;
    var greaterThan = 62;
    exports.greaterThan = greaterThan;
    var space = 32;
    exports.space = space;
    var singleQuote = 39;
    exports.singleQuote = singleQuote;
    var doubleQuote = 34;
    exports.doubleQuote = doubleQuote;
    var slash = 47;
    exports.slash = slash;
    var bang = 33;
    exports.bang = bang;
    var backslash = 92;
    exports.backslash = backslash;
    var cr = 13;
    exports.cr = cr;
    var feed = 12;
    exports.feed = feed;
    var newline = 10;
    exports.newline = newline;
    var tab = 9;
    exports.tab = tab;
    var str = singleQuote;
    exports.str = str;
    var comment = -1;
    exports.comment = comment;
    var word = -2;
    exports.word = word;
    var combinator = -3;
    exports.combinator = combinator;
  }
});

// node_modules/postcss-selector-parser/dist/tokenize.js
var require_tokenize = __commonJS({
  "node_modules/postcss-selector-parser/dist/tokenize.js"(exports) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = tokenize;
    exports.FIELDS = void 0;
    var t = _interopRequireWildcard(require_tokenTypes());
    var _unescapable;
    var _wordDelimiters;
    function _getRequireWildcardCache() {
      if (typeof WeakMap !== "function") return null;
      var cache = /* @__PURE__ */ new WeakMap();
      _getRequireWildcardCache = function _getRequireWildcardCache2() {
        return cache;
      };
      return cache;
    }
    function _interopRequireWildcard(obj) {
      if (obj && obj.__esModule) {
        return obj;
      }
      if (obj === null || typeof obj !== "object" && typeof obj !== "function") {
        return { "default": obj };
      }
      var cache = _getRequireWildcardCache();
      if (cache && cache.has(obj)) {
        return cache.get(obj);
      }
      var newObj = {};
      var hasPropertyDescriptor = Object.defineProperty && Object.getOwnPropertyDescriptor;
      for (var key in obj) {
        if (Object.prototype.hasOwnProperty.call(obj, key)) {
          var desc = hasPropertyDescriptor ? Object.getOwnPropertyDescriptor(obj, key) : null;
          if (desc && (desc.get || desc.set)) {
            Object.defineProperty(newObj, key, desc);
          } else {
            newObj[key] = obj[key];
          }
        }
      }
      newObj["default"] = obj;
      if (cache) {
        cache.set(obj, newObj);
      }
      return newObj;
    }
    var unescapable = (_unescapable = {}, _unescapable[t.tab] = true, _unescapable[t.newline] = true, _unescapable[t.cr] = true, _unescapable[t.feed] = true, _unescapable);
    var wordDelimiters = (_wordDelimiters = {}, _wordDelimiters[t.space] = true, _wordDelimiters[t.tab] = true, _wordDelimiters[t.newline] = true, _wordDelimiters[t.cr] = true, _wordDelimiters[t.feed] = true, _wordDelimiters[t.ampersand] = true, _wordDelimiters[t.asterisk] = true, _wordDelimiters[t.bang] = true, _wordDelimiters[t.comma] = true, _wordDelimiters[t.colon] = true, _wordDelimiters[t.semicolon] = true, _wordDelimiters[t.openParenthesis] = true, _wordDelimiters[t.closeParenthesis] = true, _wordDelimiters[t.openSquare] = true, _wordDelimiters[t.closeSquare] = true, _wordDelimiters[t.singleQuote] = true, _wordDelimiters[t.doubleQuote] = true, _wordDelimiters[t.plus] = true, _wordDelimiters[t.pipe] = true, _wordDelimiters[t.tilde] = true, _wordDelimiters[t.greaterThan] = true, _wordDelimiters[t.equals] = true, _wordDelimiters[t.dollar] = true, _wordDelimiters[t.caret] = true, _wordDelimiters[t.slash] = true, _wordDelimiters);
    var hex = {};
    var hexChars = "0123456789abcdefABCDEF";
    for (i = 0; i < hexChars.length; i++) {
      hex[hexChars.charCodeAt(i)] = true;
    }
    var i;
    function consumeWord(css, start) {
      var next = start;
      var code;
      do {
        code = css.charCodeAt(next);
        if (wordDelimiters[code]) {
          return next - 1;
        } else if (code === t.backslash) {
          next = consumeEscape(css, next) + 1;
        } else {
          next++;
        }
      } while (next < css.length);
      return next - 1;
    }
    function consumeEscape(css, start) {
      var next = start;
      var code = css.charCodeAt(next + 1);
      if (unescapable[code]) {
      } else if (hex[code]) {
        var hexDigits = 0;
        do {
          next++;
          hexDigits++;
          code = css.charCodeAt(next + 1);
        } while (hex[code] && hexDigits < 6);
        if (hexDigits < 6 && code === t.space) {
          next++;
        }
      } else {
        next++;
      }
      return next;
    }
    var FIELDS = {
      TYPE: 0,
      START_LINE: 1,
      START_COL: 2,
      END_LINE: 3,
      END_COL: 4,
      START_POS: 5,
      END_POS: 6
    };
    exports.FIELDS = FIELDS;
    function tokenize(input) {
      var tokens = [];
      var css = input.css.valueOf();
      var _css = css, length = _css.length;
      var offset = -1;
      var line = 1;
      var start = 0;
      var end = 0;
      var code, content, endColumn, endLine, escaped, escapePos, last, lines, next, nextLine, nextOffset, quote, tokenType;
      function unclosed(what, fix) {
        if (input.safe) {
          css += fix;
          next = css.length - 1;
        } else {
          throw input.error("Unclosed " + what, line, start - offset, start);
        }
      }
      while (start < length) {
        code = css.charCodeAt(start);
        if (code === t.newline) {
          offset = start;
          line += 1;
        }
        switch (code) {
          case t.space:
          case t.tab:
          case t.newline:
          case t.cr:
          case t.feed:
            next = start;
            do {
              next += 1;
              code = css.charCodeAt(next);
              if (code === t.newline) {
                offset = next;
                line += 1;
              }
            } while (code === t.space || code === t.newline || code === t.tab || code === t.cr || code === t.feed);
            tokenType = t.space;
            endLine = line;
            endColumn = next - offset - 1;
            end = next;
            break;
          case t.plus:
          case t.greaterThan:
          case t.tilde:
          case t.pipe:
            next = start;
            do {
              next += 1;
              code = css.charCodeAt(next);
            } while (code === t.plus || code === t.greaterThan || code === t.tilde || code === t.pipe);
            tokenType = t.combinator;
            endLine = line;
            endColumn = start - offset;
            end = next;
            break;
          case t.asterisk:
          case t.ampersand:
          case t.bang:
          case t.comma:
          case t.equals:
          case t.dollar:
          case t.caret:
          case t.openSquare:
          case t.closeSquare:
          case t.colon:
          case t.semicolon:
          case t.openParenthesis:
          case t.closeParenthesis:
            next = start;
            tokenType = code;
            endLine = line;
            endColumn = start - offset;
            end = next + 1;
            break;
          case t.singleQuote:
          case t.doubleQuote:
            quote = code === t.singleQuote ? "'" : '"';
            next = start;
            do {
              escaped = false;
              next = css.indexOf(quote, next + 1);
              if (next === -1) {
                unclosed("quote", quote);
              }
              escapePos = next;
              while (css.charCodeAt(escapePos - 1) === t.backslash) {
                escapePos -= 1;
                escaped = !escaped;
              }
            } while (escaped);
            tokenType = t.str;
            endLine = line;
            endColumn = start - offset;
            end = next + 1;
            break;
          default:
            if (code === t.slash && css.charCodeAt(start + 1) === t.asterisk) {
              next = css.indexOf("*/", start + 2) + 1;
              if (next === 0) {
                unclosed("comment", "*/");
              }
              content = css.slice(start, next + 1);
              lines = content.split("\n");
              last = lines.length - 1;
              if (last > 0) {
                nextLine = line + last;
                nextOffset = next - lines[last].length;
              } else {
                nextLine = line;
                nextOffset = offset;
              }
              tokenType = t.comment;
              line = nextLine;
              endLine = nextLine;
              endColumn = next - nextOffset;
            } else if (code === t.slash) {
              next = start;
              tokenType = code;
              endLine = line;
              endColumn = start - offset;
              end = next + 1;
            } else {
              next = consumeWord(css, start);
              tokenType = t.word;
              endLine = line;
              endColumn = next - offset;
            }
            end = next + 1;
            break;
        }
        tokens.push([
          tokenType,
          // [0] Token type
          line,
          // [1] Starting line
          start - offset,
          // [2] Starting column
          endLine,
          // [3] Ending line
          endColumn,
          // [4] Ending column
          start,
          // [5] Start position / Source index
          end
          // [6] End position
        ]);
        if (nextOffset) {
          offset = nextOffset;
          nextOffset = null;
        }
        start = end;
      }
      return tokens;
    }
  }
});

// node_modules/postcss-selector-parser/dist/parser.js
var require_parser = __commonJS({
  "node_modules/postcss-selector-parser/dist/parser.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = void 0;
    var _root = _interopRequireDefault(require_root());
    var _selector = _interopRequireDefault(require_selector());
    var _className = _interopRequireDefault(require_className());
    var _comment = _interopRequireDefault(require_comment());
    var _id = _interopRequireDefault(require_id());
    var _tag = _interopRequireDefault(require_tag());
    var _string = _interopRequireDefault(require_string());
    var _pseudo = _interopRequireDefault(require_pseudo());
    var _attribute = _interopRequireWildcard(require_attribute());
    var _universal = _interopRequireDefault(require_universal());
    var _combinator = _interopRequireDefault(require_combinator());
    var _nesting = _interopRequireDefault(require_nesting());
    var _sortAscending = _interopRequireDefault(require_sortAscending());
    var _tokenize = _interopRequireWildcard(require_tokenize());
    var tokens = _interopRequireWildcard(require_tokenTypes());
    var types = _interopRequireWildcard(require_types());
    var _util = require_util();
    var _WHITESPACE_TOKENS;
    var _Object$assign;
    function _getRequireWildcardCache() {
      if (typeof WeakMap !== "function") return null;
      var cache = /* @__PURE__ */ new WeakMap();
      _getRequireWildcardCache = function _getRequireWildcardCache2() {
        return cache;
      };
      return cache;
    }
    function _interopRequireWildcard(obj) {
      if (obj && obj.__esModule) {
        return obj;
      }
      if (obj === null || typeof obj !== "object" && typeof obj !== "function") {
        return { "default": obj };
      }
      var cache = _getRequireWildcardCache();
      if (cache && cache.has(obj)) {
        return cache.get(obj);
      }
      var newObj = {};
      var hasPropertyDescriptor = Object.defineProperty && Object.getOwnPropertyDescriptor;
      for (var key in obj) {
        if (Object.prototype.hasOwnProperty.call(obj, key)) {
          var desc = hasPropertyDescriptor ? Object.getOwnPropertyDescriptor(obj, key) : null;
          if (desc && (desc.get || desc.set)) {
            Object.defineProperty(newObj, key, desc);
          } else {
            newObj[key] = obj[key];
          }
        }
      }
      newObj["default"] = obj;
      if (cache) {
        cache.set(obj, newObj);
      }
      return newObj;
    }
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _defineProperties(target, props) {
      for (var i = 0; i < props.length; i++) {
        var descriptor = props[i];
        descriptor.enumerable = descriptor.enumerable || false;
        descriptor.configurable = true;
        if ("value" in descriptor) descriptor.writable = true;
        Object.defineProperty(target, descriptor.key, descriptor);
      }
    }
    function _createClass(Constructor, protoProps, staticProps) {
      if (protoProps) _defineProperties(Constructor.prototype, protoProps);
      if (staticProps) _defineProperties(Constructor, staticProps);
      return Constructor;
    }
    var WHITESPACE_TOKENS = (_WHITESPACE_TOKENS = {}, _WHITESPACE_TOKENS[tokens.space] = true, _WHITESPACE_TOKENS[tokens.cr] = true, _WHITESPACE_TOKENS[tokens.feed] = true, _WHITESPACE_TOKENS[tokens.newline] = true, _WHITESPACE_TOKENS[tokens.tab] = true, _WHITESPACE_TOKENS);
    var WHITESPACE_EQUIV_TOKENS = Object.assign({}, WHITESPACE_TOKENS, (_Object$assign = {}, _Object$assign[tokens.comment] = true, _Object$assign));
    function tokenStart(token) {
      return {
        line: token[_tokenize.FIELDS.START_LINE],
        column: token[_tokenize.FIELDS.START_COL]
      };
    }
    function tokenEnd(token) {
      return {
        line: token[_tokenize.FIELDS.END_LINE],
        column: token[_tokenize.FIELDS.END_COL]
      };
    }
    function getSource(startLine, startColumn, endLine, endColumn) {
      return {
        start: {
          line: startLine,
          column: startColumn
        },
        end: {
          line: endLine,
          column: endColumn
        }
      };
    }
    function getTokenSource(token) {
      return getSource(token[_tokenize.FIELDS.START_LINE], token[_tokenize.FIELDS.START_COL], token[_tokenize.FIELDS.END_LINE], token[_tokenize.FIELDS.END_COL]);
    }
    function getTokenSourceSpan(startToken, endToken) {
      if (!startToken) {
        return void 0;
      }
      return getSource(startToken[_tokenize.FIELDS.START_LINE], startToken[_tokenize.FIELDS.START_COL], endToken[_tokenize.FIELDS.END_LINE], endToken[_tokenize.FIELDS.END_COL]);
    }
    function unescapeProp(node, prop) {
      var value = node[prop];
      if (typeof value !== "string") {
        return;
      }
      if (value.indexOf("\\") !== -1) {
        (0, _util.ensureObject)(node, "raws");
        node[prop] = (0, _util.unesc)(value);
        if (node.raws[prop] === void 0) {
          node.raws[prop] = value;
        }
      }
      return node;
    }
    function indexesOf(array, item) {
      var i = -1;
      var indexes = [];
      while ((i = array.indexOf(item, i + 1)) !== -1) {
        indexes.push(i);
      }
      return indexes;
    }
    function uniqs() {
      var list = Array.prototype.concat.apply([], arguments);
      return list.filter(function(item, i) {
        return i === list.indexOf(item);
      });
    }
    var Parser = /* @__PURE__ */ function() {
      function Parser2(rule, options) {
        if (options === void 0) {
          options = {};
        }
        this.rule = rule;
        this.options = Object.assign({
          lossy: false,
          safe: false
        }, options);
        this.position = 0;
        this.css = typeof this.rule === "string" ? this.rule : this.rule.selector;
        this.tokens = (0, _tokenize["default"])({
          css: this.css,
          error: this._errorGenerator(),
          safe: this.options.safe
        });
        var rootSource = getTokenSourceSpan(this.tokens[0], this.tokens[this.tokens.length - 1]);
        this.root = new _root["default"]({
          source: rootSource
        });
        this.root.errorGenerator = this._errorGenerator();
        var selector = new _selector["default"]({
          source: {
            start: {
              line: 1,
              column: 1
            }
          }
        });
        this.root.append(selector);
        this.current = selector;
        this.loop();
      }
      var _proto = Parser2.prototype;
      _proto._errorGenerator = function _errorGenerator() {
        var _this = this;
        return function(message, errorOptions) {
          if (typeof _this.rule === "string") {
            return new Error(message);
          }
          return _this.rule.error(message, errorOptions);
        };
      };
      _proto.attribute = function attribute() {
        var attr = [];
        var startingToken = this.currToken;
        this.position++;
        while (this.position < this.tokens.length && this.currToken[_tokenize.FIELDS.TYPE] !== tokens.closeSquare) {
          attr.push(this.currToken);
          this.position++;
        }
        if (this.currToken[_tokenize.FIELDS.TYPE] !== tokens.closeSquare) {
          return this.expected("closing square bracket", this.currToken[_tokenize.FIELDS.START_POS]);
        }
        var len = attr.length;
        var node = {
          source: getSource(startingToken[1], startingToken[2], this.currToken[3], this.currToken[4]),
          sourceIndex: startingToken[_tokenize.FIELDS.START_POS]
        };
        if (len === 1 && !~[tokens.word].indexOf(attr[0][_tokenize.FIELDS.TYPE])) {
          return this.expected("attribute", attr[0][_tokenize.FIELDS.START_POS]);
        }
        var pos = 0;
        var spaceBefore = "";
        var commentBefore = "";
        var lastAdded = null;
        var spaceAfterMeaningfulToken = false;
        while (pos < len) {
          var token = attr[pos];
          var content = this.content(token);
          var next = attr[pos + 1];
          switch (token[_tokenize.FIELDS.TYPE]) {
            case tokens.space:
              spaceAfterMeaningfulToken = true;
              if (this.options.lossy) {
                break;
              }
              if (lastAdded) {
                (0, _util.ensureObject)(node, "spaces", lastAdded);
                var prevContent = node.spaces[lastAdded].after || "";
                node.spaces[lastAdded].after = prevContent + content;
                var existingComment = (0, _util.getProp)(node, "raws", "spaces", lastAdded, "after") || null;
                if (existingComment) {
                  node.raws.spaces[lastAdded].after = existingComment + content;
                }
              } else {
                spaceBefore = spaceBefore + content;
                commentBefore = commentBefore + content;
              }
              break;
            case tokens.asterisk:
              if (next[_tokenize.FIELDS.TYPE] === tokens.equals) {
                node.operator = content;
                lastAdded = "operator";
              } else if ((!node.namespace || lastAdded === "namespace" && !spaceAfterMeaningfulToken) && next) {
                if (spaceBefore) {
                  (0, _util.ensureObject)(node, "spaces", "attribute");
                  node.spaces.attribute.before = spaceBefore;
                  spaceBefore = "";
                }
                if (commentBefore) {
                  (0, _util.ensureObject)(node, "raws", "spaces", "attribute");
                  node.raws.spaces.attribute.before = spaceBefore;
                  commentBefore = "";
                }
                node.namespace = (node.namespace || "") + content;
                var rawValue = (0, _util.getProp)(node, "raws", "namespace") || null;
                if (rawValue) {
                  node.raws.namespace += content;
                }
                lastAdded = "namespace";
              }
              spaceAfterMeaningfulToken = false;
              break;
            case tokens.dollar:
              if (lastAdded === "value") {
                var oldRawValue = (0, _util.getProp)(node, "raws", "value");
                node.value += "$";
                if (oldRawValue) {
                  node.raws.value = oldRawValue + "$";
                }
                break;
              }
            case tokens.caret:
              if (next[_tokenize.FIELDS.TYPE] === tokens.equals) {
                node.operator = content;
                lastAdded = "operator";
              }
              spaceAfterMeaningfulToken = false;
              break;
            case tokens.combinator:
              if (content === "~" && next[_tokenize.FIELDS.TYPE] === tokens.equals) {
                node.operator = content;
                lastAdded = "operator";
              }
              if (content !== "|") {
                spaceAfterMeaningfulToken = false;
                break;
              }
              if (next[_tokenize.FIELDS.TYPE] === tokens.equals) {
                node.operator = content;
                lastAdded = "operator";
              } else if (!node.namespace && !node.attribute) {
                node.namespace = true;
              }
              spaceAfterMeaningfulToken = false;
              break;
            case tokens.word:
              if (next && this.content(next) === "|" && attr[pos + 2] && attr[pos + 2][_tokenize.FIELDS.TYPE] !== tokens.equals && // this look-ahead probably fails with comment nodes involved.
              !node.operator && !node.namespace) {
                node.namespace = content;
                lastAdded = "namespace";
              } else if (!node.attribute || lastAdded === "attribute" && !spaceAfterMeaningfulToken) {
                if (spaceBefore) {
                  (0, _util.ensureObject)(node, "spaces", "attribute");
                  node.spaces.attribute.before = spaceBefore;
                  spaceBefore = "";
                }
                if (commentBefore) {
                  (0, _util.ensureObject)(node, "raws", "spaces", "attribute");
                  node.raws.spaces.attribute.before = commentBefore;
                  commentBefore = "";
                }
                node.attribute = (node.attribute || "") + content;
                var _rawValue = (0, _util.getProp)(node, "raws", "attribute") || null;
                if (_rawValue) {
                  node.raws.attribute += content;
                }
                lastAdded = "attribute";
              } else if (!node.value && node.value !== "" || lastAdded === "value" && !spaceAfterMeaningfulToken) {
                var _unescaped = (0, _util.unesc)(content);
                var _oldRawValue = (0, _util.getProp)(node, "raws", "value") || "";
                var oldValue = node.value || "";
                node.value = oldValue + _unescaped;
                node.quoteMark = null;
                if (_unescaped !== content || _oldRawValue) {
                  (0, _util.ensureObject)(node, "raws");
                  node.raws.value = (_oldRawValue || oldValue) + content;
                }
                lastAdded = "value";
              } else {
                var insensitive = content === "i" || content === "I";
                if ((node.value || node.value === "") && (node.quoteMark || spaceAfterMeaningfulToken)) {
                  node.insensitive = insensitive;
                  if (!insensitive || content === "I") {
                    (0, _util.ensureObject)(node, "raws");
                    node.raws.insensitiveFlag = content;
                  }
                  lastAdded = "insensitive";
                  if (spaceBefore) {
                    (0, _util.ensureObject)(node, "spaces", "insensitive");
                    node.spaces.insensitive.before = spaceBefore;
                    spaceBefore = "";
                  }
                  if (commentBefore) {
                    (0, _util.ensureObject)(node, "raws", "spaces", "insensitive");
                    node.raws.spaces.insensitive.before = commentBefore;
                    commentBefore = "";
                  }
                } else if (node.value || node.value === "") {
                  lastAdded = "value";
                  node.value += content;
                  if (node.raws.value) {
                    node.raws.value += content;
                  }
                }
              }
              spaceAfterMeaningfulToken = false;
              break;
            case tokens.str:
              if (!node.attribute || !node.operator) {
                return this.error("Expected an attribute followed by an operator preceding the string.", {
                  index: token[_tokenize.FIELDS.START_POS]
                });
              }
              var _unescapeValue = (0, _attribute.unescapeValue)(content), unescaped = _unescapeValue.unescaped, quoteMark = _unescapeValue.quoteMark;
              node.value = unescaped;
              node.quoteMark = quoteMark;
              lastAdded = "value";
              (0, _util.ensureObject)(node, "raws");
              node.raws.value = content;
              spaceAfterMeaningfulToken = false;
              break;
            case tokens.equals:
              if (!node.attribute) {
                return this.expected("attribute", token[_tokenize.FIELDS.START_POS], content);
              }
              if (node.value) {
                return this.error('Unexpected "=" found; an operator was already defined.', {
                  index: token[_tokenize.FIELDS.START_POS]
                });
              }
              node.operator = node.operator ? node.operator + content : content;
              lastAdded = "operator";
              spaceAfterMeaningfulToken = false;
              break;
            case tokens.comment:
              if (lastAdded) {
                if (spaceAfterMeaningfulToken || next && next[_tokenize.FIELDS.TYPE] === tokens.space || lastAdded === "insensitive") {
                  var lastComment = (0, _util.getProp)(node, "spaces", lastAdded, "after") || "";
                  var rawLastComment = (0, _util.getProp)(node, "raws", "spaces", lastAdded, "after") || lastComment;
                  (0, _util.ensureObject)(node, "raws", "spaces", lastAdded);
                  node.raws.spaces[lastAdded].after = rawLastComment + content;
                } else {
                  var lastValue = node[lastAdded] || "";
                  var rawLastValue = (0, _util.getProp)(node, "raws", lastAdded) || lastValue;
                  (0, _util.ensureObject)(node, "raws");
                  node.raws[lastAdded] = rawLastValue + content;
                }
              } else {
                commentBefore = commentBefore + content;
              }
              break;
            default:
              return this.error('Unexpected "' + content + '" found.', {
                index: token[_tokenize.FIELDS.START_POS]
              });
          }
          pos++;
        }
        unescapeProp(node, "attribute");
        unescapeProp(node, "namespace");
        this.newNode(new _attribute["default"](node));
        this.position++;
      };
      _proto.parseWhitespaceEquivalentTokens = function parseWhitespaceEquivalentTokens(stopPosition) {
        if (stopPosition < 0) {
          stopPosition = this.tokens.length;
        }
        var startPosition = this.position;
        var nodes = [];
        var space = "";
        var lastComment = void 0;
        do {
          if (WHITESPACE_TOKENS[this.currToken[_tokenize.FIELDS.TYPE]]) {
            if (!this.options.lossy) {
              space += this.content();
            }
          } else if (this.currToken[_tokenize.FIELDS.TYPE] === tokens.comment) {
            var spaces = {};
            if (space) {
              spaces.before = space;
              space = "";
            }
            lastComment = new _comment["default"]({
              value: this.content(),
              source: getTokenSource(this.currToken),
              sourceIndex: this.currToken[_tokenize.FIELDS.START_POS],
              spaces
            });
            nodes.push(lastComment);
          }
        } while (++this.position < stopPosition);
        if (space) {
          if (lastComment) {
            lastComment.spaces.after = space;
          } else if (!this.options.lossy) {
            var firstToken = this.tokens[startPosition];
            var lastToken = this.tokens[this.position - 1];
            nodes.push(new _string["default"]({
              value: "",
              source: getSource(firstToken[_tokenize.FIELDS.START_LINE], firstToken[_tokenize.FIELDS.START_COL], lastToken[_tokenize.FIELDS.END_LINE], lastToken[_tokenize.FIELDS.END_COL]),
              sourceIndex: firstToken[_tokenize.FIELDS.START_POS],
              spaces: {
                before: space,
                after: ""
              }
            }));
          }
        }
        return nodes;
      };
      _proto.convertWhitespaceNodesToSpace = function convertWhitespaceNodesToSpace(nodes, requiredSpace) {
        var _this2 = this;
        if (requiredSpace === void 0) {
          requiredSpace = false;
        }
        var space = "";
        var rawSpace = "";
        nodes.forEach(function(n) {
          var spaceBefore = _this2.lossySpace(n.spaces.before, requiredSpace);
          var rawSpaceBefore = _this2.lossySpace(n.rawSpaceBefore, requiredSpace);
          space += spaceBefore + _this2.lossySpace(n.spaces.after, requiredSpace && spaceBefore.length === 0);
          rawSpace += spaceBefore + n.value + _this2.lossySpace(n.rawSpaceAfter, requiredSpace && rawSpaceBefore.length === 0);
        });
        if (rawSpace === space) {
          rawSpace = void 0;
        }
        var result = {
          space,
          rawSpace
        };
        return result;
      };
      _proto.isNamedCombinator = function isNamedCombinator(position) {
        if (position === void 0) {
          position = this.position;
        }
        return this.tokens[position + 0] && this.tokens[position + 0][_tokenize.FIELDS.TYPE] === tokens.slash && this.tokens[position + 1] && this.tokens[position + 1][_tokenize.FIELDS.TYPE] === tokens.word && this.tokens[position + 2] && this.tokens[position + 2][_tokenize.FIELDS.TYPE] === tokens.slash;
      };
      _proto.namedCombinator = function namedCombinator() {
        if (this.isNamedCombinator()) {
          var nameRaw = this.content(this.tokens[this.position + 1]);
          var name = (0, _util.unesc)(nameRaw).toLowerCase();
          var raws = {};
          if (name !== nameRaw) {
            raws.value = "/" + nameRaw + "/";
          }
          var node = new _combinator["default"]({
            value: "/" + name + "/",
            source: getSource(this.currToken[_tokenize.FIELDS.START_LINE], this.currToken[_tokenize.FIELDS.START_COL], this.tokens[this.position + 2][_tokenize.FIELDS.END_LINE], this.tokens[this.position + 2][_tokenize.FIELDS.END_COL]),
            sourceIndex: this.currToken[_tokenize.FIELDS.START_POS],
            raws
          });
          this.position = this.position + 3;
          return node;
        } else {
          this.unexpected();
        }
      };
      _proto.combinator = function combinator() {
        var _this3 = this;
        if (this.content() === "|") {
          return this.namespace();
        }
        var nextSigTokenPos = this.locateNextMeaningfulToken(this.position);
        if (nextSigTokenPos < 0 || this.tokens[nextSigTokenPos][_tokenize.FIELDS.TYPE] === tokens.comma) {
          var nodes = this.parseWhitespaceEquivalentTokens(nextSigTokenPos);
          if (nodes.length > 0) {
            var last = this.current.last;
            if (last) {
              var _this$convertWhitespa = this.convertWhitespaceNodesToSpace(nodes), space = _this$convertWhitespa.space, rawSpace = _this$convertWhitespa.rawSpace;
              if (rawSpace !== void 0) {
                last.rawSpaceAfter += rawSpace;
              }
              last.spaces.after += space;
            } else {
              nodes.forEach(function(n) {
                return _this3.newNode(n);
              });
            }
          }
          return;
        }
        var firstToken = this.currToken;
        var spaceOrDescendantSelectorNodes = void 0;
        if (nextSigTokenPos > this.position) {
          spaceOrDescendantSelectorNodes = this.parseWhitespaceEquivalentTokens(nextSigTokenPos);
        }
        var node;
        if (this.isNamedCombinator()) {
          node = this.namedCombinator();
        } else if (this.currToken[_tokenize.FIELDS.TYPE] === tokens.combinator) {
          node = new _combinator["default"]({
            value: this.content(),
            source: getTokenSource(this.currToken),
            sourceIndex: this.currToken[_tokenize.FIELDS.START_POS]
          });
          this.position++;
        } else if (WHITESPACE_TOKENS[this.currToken[_tokenize.FIELDS.TYPE]]) {
        } else if (!spaceOrDescendantSelectorNodes) {
          this.unexpected();
        }
        if (node) {
          if (spaceOrDescendantSelectorNodes) {
            var _this$convertWhitespa2 = this.convertWhitespaceNodesToSpace(spaceOrDescendantSelectorNodes), _space = _this$convertWhitespa2.space, _rawSpace = _this$convertWhitespa2.rawSpace;
            node.spaces.before = _space;
            node.rawSpaceBefore = _rawSpace;
          }
        } else {
          var _this$convertWhitespa3 = this.convertWhitespaceNodesToSpace(spaceOrDescendantSelectorNodes, true), _space2 = _this$convertWhitespa3.space, _rawSpace2 = _this$convertWhitespa3.rawSpace;
          if (!_rawSpace2) {
            _rawSpace2 = _space2;
          }
          var spaces = {};
          var raws = {
            spaces: {}
          };
          if (_space2.endsWith(" ") && _rawSpace2.endsWith(" ")) {
            spaces.before = _space2.slice(0, _space2.length - 1);
            raws.spaces.before = _rawSpace2.slice(0, _rawSpace2.length - 1);
          } else if (_space2.startsWith(" ") && _rawSpace2.startsWith(" ")) {
            spaces.after = _space2.slice(1);
            raws.spaces.after = _rawSpace2.slice(1);
          } else {
            raws.value = _rawSpace2;
          }
          node = new _combinator["default"]({
            value: " ",
            source: getTokenSourceSpan(firstToken, this.tokens[this.position - 1]),
            sourceIndex: firstToken[_tokenize.FIELDS.START_POS],
            spaces,
            raws
          });
        }
        if (this.currToken && this.currToken[_tokenize.FIELDS.TYPE] === tokens.space) {
          node.spaces.after = this.optionalSpace(this.content());
          this.position++;
        }
        return this.newNode(node);
      };
      _proto.comma = function comma() {
        if (this.position === this.tokens.length - 1) {
          this.root.trailingComma = true;
          this.position++;
          return;
        }
        this.current._inferEndPosition();
        var selector = new _selector["default"]({
          source: {
            start: tokenStart(this.tokens[this.position + 1])
          }
        });
        this.current.parent.append(selector);
        this.current = selector;
        this.position++;
      };
      _proto.comment = function comment() {
        var current = this.currToken;
        this.newNode(new _comment["default"]({
          value: this.content(),
          source: getTokenSource(current),
          sourceIndex: current[_tokenize.FIELDS.START_POS]
        }));
        this.position++;
      };
      _proto.error = function error(message, opts) {
        throw this.root.error(message, opts);
      };
      _proto.missingBackslash = function missingBackslash() {
        return this.error("Expected a backslash preceding the semicolon.", {
          index: this.currToken[_tokenize.FIELDS.START_POS]
        });
      };
      _proto.missingParenthesis = function missingParenthesis() {
        return this.expected("opening parenthesis", this.currToken[_tokenize.FIELDS.START_POS]);
      };
      _proto.missingSquareBracket = function missingSquareBracket() {
        return this.expected("opening square bracket", this.currToken[_tokenize.FIELDS.START_POS]);
      };
      _proto.unexpected = function unexpected() {
        return this.error("Unexpected '" + this.content() + "'. Escaping special characters with \\ may help.", this.currToken[_tokenize.FIELDS.START_POS]);
      };
      _proto.namespace = function namespace() {
        var before = this.prevToken && this.content(this.prevToken) || true;
        if (this.nextToken[_tokenize.FIELDS.TYPE] === tokens.word) {
          this.position++;
          return this.word(before);
        } else if (this.nextToken[_tokenize.FIELDS.TYPE] === tokens.asterisk) {
          this.position++;
          return this.universal(before);
        }
      };
      _proto.nesting = function nesting() {
        if (this.nextToken) {
          var nextContent = this.content(this.nextToken);
          if (nextContent === "|") {
            this.position++;
            return;
          }
        }
        var current = this.currToken;
        this.newNode(new _nesting["default"]({
          value: this.content(),
          source: getTokenSource(current),
          sourceIndex: current[_tokenize.FIELDS.START_POS]
        }));
        this.position++;
      };
      _proto.parentheses = function parentheses() {
        var last = this.current.last;
        var unbalanced = 1;
        this.position++;
        if (last && last.type === types.PSEUDO) {
          var selector = new _selector["default"]({
            source: {
              start: tokenStart(this.tokens[this.position - 1])
            }
          });
          var cache = this.current;
          last.append(selector);
          this.current = selector;
          while (this.position < this.tokens.length && unbalanced) {
            if (this.currToken[_tokenize.FIELDS.TYPE] === tokens.openParenthesis) {
              unbalanced++;
            }
            if (this.currToken[_tokenize.FIELDS.TYPE] === tokens.closeParenthesis) {
              unbalanced--;
            }
            if (unbalanced) {
              this.parse();
            } else {
              this.current.source.end = tokenEnd(this.currToken);
              this.current.parent.source.end = tokenEnd(this.currToken);
              this.position++;
            }
          }
          this.current = cache;
        } else {
          var parenStart = this.currToken;
          var parenValue = "(";
          var parenEnd;
          while (this.position < this.tokens.length && unbalanced) {
            if (this.currToken[_tokenize.FIELDS.TYPE] === tokens.openParenthesis) {
              unbalanced++;
            }
            if (this.currToken[_tokenize.FIELDS.TYPE] === tokens.closeParenthesis) {
              unbalanced--;
            }
            parenEnd = this.currToken;
            parenValue += this.parseParenthesisToken(this.currToken);
            this.position++;
          }
          if (last) {
            last.appendToPropertyAndEscape("value", parenValue, parenValue);
          } else {
            this.newNode(new _string["default"]({
              value: parenValue,
              source: getSource(parenStart[_tokenize.FIELDS.START_LINE], parenStart[_tokenize.FIELDS.START_COL], parenEnd[_tokenize.FIELDS.END_LINE], parenEnd[_tokenize.FIELDS.END_COL]),
              sourceIndex: parenStart[_tokenize.FIELDS.START_POS]
            }));
          }
        }
        if (unbalanced) {
          return this.expected("closing parenthesis", this.currToken[_tokenize.FIELDS.START_POS]);
        }
      };
      _proto.pseudo = function pseudo() {
        var _this4 = this;
        var pseudoStr = "";
        var startingToken = this.currToken;
        while (this.currToken && this.currToken[_tokenize.FIELDS.TYPE] === tokens.colon) {
          pseudoStr += this.content();
          this.position++;
        }
        if (!this.currToken) {
          return this.expected(["pseudo-class", "pseudo-element"], this.position - 1);
        }
        if (this.currToken[_tokenize.FIELDS.TYPE] === tokens.word) {
          this.splitWord(false, function(first, length) {
            pseudoStr += first;
            _this4.newNode(new _pseudo["default"]({
              value: pseudoStr,
              source: getTokenSourceSpan(startingToken, _this4.currToken),
              sourceIndex: startingToken[_tokenize.FIELDS.START_POS]
            }));
            if (length > 1 && _this4.nextToken && _this4.nextToken[_tokenize.FIELDS.TYPE] === tokens.openParenthesis) {
              _this4.error("Misplaced parenthesis.", {
                index: _this4.nextToken[_tokenize.FIELDS.START_POS]
              });
            }
          });
        } else {
          return this.expected(["pseudo-class", "pseudo-element"], this.currToken[_tokenize.FIELDS.START_POS]);
        }
      };
      _proto.space = function space() {
        var content = this.content();
        if (this.position === 0 || this.prevToken[_tokenize.FIELDS.TYPE] === tokens.comma || this.prevToken[_tokenize.FIELDS.TYPE] === tokens.openParenthesis || this.current.nodes.every(function(node) {
          return node.type === "comment";
        })) {
          this.spaces = this.optionalSpace(content);
          this.position++;
        } else if (this.position === this.tokens.length - 1 || this.nextToken[_tokenize.FIELDS.TYPE] === tokens.comma || this.nextToken[_tokenize.FIELDS.TYPE] === tokens.closeParenthesis) {
          this.current.last.spaces.after = this.optionalSpace(content);
          this.position++;
        } else {
          this.combinator();
        }
      };
      _proto.string = function string() {
        var current = this.currToken;
        this.newNode(new _string["default"]({
          value: this.content(),
          source: getTokenSource(current),
          sourceIndex: current[_tokenize.FIELDS.START_POS]
        }));
        this.position++;
      };
      _proto.universal = function universal(namespace) {
        var nextToken = this.nextToken;
        if (nextToken && this.content(nextToken) === "|") {
          this.position++;
          return this.namespace();
        }
        var current = this.currToken;
        this.newNode(new _universal["default"]({
          value: this.content(),
          source: getTokenSource(current),
          sourceIndex: current[_tokenize.FIELDS.START_POS]
        }), namespace);
        this.position++;
      };
      _proto.splitWord = function splitWord(namespace, firstCallback) {
        var _this5 = this;
        var nextToken = this.nextToken;
        var word = this.content();
        while (nextToken && ~[tokens.dollar, tokens.caret, tokens.equals, tokens.word].indexOf(nextToken[_tokenize.FIELDS.TYPE])) {
          this.position++;
          var current = this.content();
          word += current;
          if (current.lastIndexOf("\\") === current.length - 1) {
            var next = this.nextToken;
            if (next && next[_tokenize.FIELDS.TYPE] === tokens.space) {
              word += this.requiredSpace(this.content(next));
              this.position++;
            }
          }
          nextToken = this.nextToken;
        }
        var hasClass = indexesOf(word, ".").filter(function(i) {
          var escapedDot = word[i - 1] === "\\";
          var isKeyframesPercent = /^\d+\.\d+%$/.test(word);
          return !escapedDot && !isKeyframesPercent;
        });
        var hasId = indexesOf(word, "#").filter(function(i) {
          return word[i - 1] !== "\\";
        });
        var interpolations = indexesOf(word, "#{");
        if (interpolations.length) {
          hasId = hasId.filter(function(hashIndex) {
            return !~interpolations.indexOf(hashIndex);
          });
        }
        var indices = (0, _sortAscending["default"])(uniqs([0].concat(hasClass, hasId)));
        indices.forEach(function(ind, i) {
          var index = indices[i + 1] || word.length;
          var value = word.slice(ind, index);
          if (i === 0 && firstCallback) {
            return firstCallback.call(_this5, value, indices.length);
          }
          var node;
          var current2 = _this5.currToken;
          var sourceIndex = current2[_tokenize.FIELDS.START_POS] + indices[i];
          var source = getSource(current2[1], current2[2] + ind, current2[3], current2[2] + (index - 1));
          if (~hasClass.indexOf(ind)) {
            var classNameOpts = {
              value: value.slice(1),
              source,
              sourceIndex
            };
            node = new _className["default"](unescapeProp(classNameOpts, "value"));
          } else if (~hasId.indexOf(ind)) {
            var idOpts = {
              value: value.slice(1),
              source,
              sourceIndex
            };
            node = new _id["default"](unescapeProp(idOpts, "value"));
          } else {
            var tagOpts = {
              value,
              source,
              sourceIndex
            };
            unescapeProp(tagOpts, "value");
            node = new _tag["default"](tagOpts);
          }
          _this5.newNode(node, namespace);
          namespace = null;
        });
        this.position++;
      };
      _proto.word = function word(namespace) {
        var nextToken = this.nextToken;
        if (nextToken && this.content(nextToken) === "|") {
          this.position++;
          return this.namespace();
        }
        return this.splitWord(namespace);
      };
      _proto.loop = function loop() {
        while (this.position < this.tokens.length) {
          this.parse(true);
        }
        this.current._inferEndPosition();
        return this.root;
      };
      _proto.parse = function parse(throwOnParenthesis) {
        switch (this.currToken[_tokenize.FIELDS.TYPE]) {
          case tokens.space:
            this.space();
            break;
          case tokens.comment:
            this.comment();
            break;
          case tokens.openParenthesis:
            this.parentheses();
            break;
          case tokens.closeParenthesis:
            if (throwOnParenthesis) {
              this.missingParenthesis();
            }
            break;
          case tokens.openSquare:
            this.attribute();
            break;
          case tokens.dollar:
          case tokens.caret:
          case tokens.equals:
          case tokens.word:
            this.word();
            break;
          case tokens.colon:
            this.pseudo();
            break;
          case tokens.comma:
            this.comma();
            break;
          case tokens.asterisk:
            this.universal();
            break;
          case tokens.ampersand:
            this.nesting();
            break;
          case tokens.slash:
          case tokens.combinator:
            this.combinator();
            break;
          case tokens.str:
            this.string();
            break;
          case tokens.closeSquare:
            this.missingSquareBracket();
          case tokens.semicolon:
            this.missingBackslash();
          default:
            this.unexpected();
        }
      };
      _proto.expected = function expected(description, index, found) {
        if (Array.isArray(description)) {
          var last = description.pop();
          description = description.join(", ") + " or " + last;
        }
        var an = /^[aeiou]/.test(description[0]) ? "an" : "a";
        if (!found) {
          return this.error("Expected " + an + " " + description + ".", {
            index
          });
        }
        return this.error("Expected " + an + " " + description + ', found "' + found + '" instead.', {
          index
        });
      };
      _proto.requiredSpace = function requiredSpace(space) {
        return this.options.lossy ? " " : space;
      };
      _proto.optionalSpace = function optionalSpace(space) {
        return this.options.lossy ? "" : space;
      };
      _proto.lossySpace = function lossySpace(space, required) {
        if (this.options.lossy) {
          return required ? " " : "";
        } else {
          return space;
        }
      };
      _proto.parseParenthesisToken = function parseParenthesisToken(token) {
        var content = this.content(token);
        if (token[_tokenize.FIELDS.TYPE] === tokens.space) {
          return this.requiredSpace(content);
        } else {
          return content;
        }
      };
      _proto.newNode = function newNode(node, namespace) {
        if (namespace) {
          if (/^ +$/.test(namespace)) {
            if (!this.options.lossy) {
              this.spaces = (this.spaces || "") + namespace;
            }
            namespace = true;
          }
          node.namespace = namespace;
          unescapeProp(node, "namespace");
        }
        if (this.spaces) {
          node.spaces.before = this.spaces;
          this.spaces = "";
        }
        return this.current.append(node);
      };
      _proto.content = function content(token) {
        if (token === void 0) {
          token = this.currToken;
        }
        return this.css.slice(token[_tokenize.FIELDS.START_POS], token[_tokenize.FIELDS.END_POS]);
      };
      _proto.locateNextMeaningfulToken = function locateNextMeaningfulToken(startPosition) {
        if (startPosition === void 0) {
          startPosition = this.position + 1;
        }
        var searchPosition = startPosition;
        while (searchPosition < this.tokens.length) {
          if (WHITESPACE_EQUIV_TOKENS[this.tokens[searchPosition][_tokenize.FIELDS.TYPE]]) {
            searchPosition++;
            continue;
          } else {
            return searchPosition;
          }
        }
        return -1;
      };
      _createClass(Parser2, [{
        key: "currToken",
        get: function get() {
          return this.tokens[this.position];
        }
      }, {
        key: "nextToken",
        get: function get() {
          return this.tokens[this.position + 1];
        }
      }, {
        key: "prevToken",
        get: function get() {
          return this.tokens[this.position - 1];
        }
      }]);
      return Parser2;
    }();
    exports["default"] = Parser;
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/processor.js
var require_processor = __commonJS({
  "node_modules/postcss-selector-parser/dist/processor.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = void 0;
    var _parser = _interopRequireDefault(require_parser());
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    var Processor = /* @__PURE__ */ function() {
      function Processor2(func, options) {
        this.func = func || function noop() {
        };
        this.funcRes = null;
        this.options = options;
      }
      var _proto = Processor2.prototype;
      _proto._shouldUpdateSelector = function _shouldUpdateSelector(rule, options) {
        if (options === void 0) {
          options = {};
        }
        var merged = Object.assign({}, this.options, options);
        if (merged.updateSelector === false) {
          return false;
        } else {
          return typeof rule !== "string";
        }
      };
      _proto._isLossy = function _isLossy(options) {
        if (options === void 0) {
          options = {};
        }
        var merged = Object.assign({}, this.options, options);
        if (merged.lossless === false) {
          return true;
        } else {
          return false;
        }
      };
      _proto._root = function _root(rule, options) {
        if (options === void 0) {
          options = {};
        }
        var parser = new _parser["default"](rule, this._parseOptions(options));
        return parser.root;
      };
      _proto._parseOptions = function _parseOptions(options) {
        return {
          lossy: this._isLossy(options)
        };
      };
      _proto._run = function _run(rule, options) {
        var _this = this;
        if (options === void 0) {
          options = {};
        }
        return new Promise(function(resolve, reject) {
          try {
            var root = _this._root(rule, options);
            Promise.resolve(_this.func(root)).then(function(transform) {
              var string = void 0;
              if (_this._shouldUpdateSelector(rule, options)) {
                string = root.toString();
                rule.selector = string;
              }
              return {
                transform,
                root,
                string
              };
            }).then(resolve, reject);
          } catch (e) {
            reject(e);
            return;
          }
        });
      };
      _proto._runSync = function _runSync(rule, options) {
        if (options === void 0) {
          options = {};
        }
        var root = this._root(rule, options);
        var transform = this.func(root);
        if (transform && typeof transform.then === "function") {
          throw new Error("Selector processor returned a promise to a synchronous call.");
        }
        var string = void 0;
        if (options.updateSelector && typeof rule !== "string") {
          string = root.toString();
          rule.selector = string;
        }
        return {
          transform,
          root,
          string
        };
      };
      _proto.ast = function ast(rule, options) {
        return this._run(rule, options).then(function(result) {
          return result.root;
        });
      };
      _proto.astSync = function astSync(rule, options) {
        return this._runSync(rule, options).root;
      };
      _proto.transform = function transform(rule, options) {
        return this._run(rule, options).then(function(result) {
          return result.transform;
        });
      };
      _proto.transformSync = function transformSync(rule, options) {
        return this._runSync(rule, options).transform;
      };
      _proto.process = function process2(rule, options) {
        return this._run(rule, options).then(function(result) {
          return result.string || result.root.toString();
        });
      };
      _proto.processSync = function processSync(rule, options) {
        var result = this._runSync(rule, options);
        return result.string || result.root.toString();
      };
      return Processor2;
    }();
    exports["default"] = Processor;
    module.exports = exports.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/constructors.js
var require_constructors = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/constructors.js"(exports) {
    "use strict";
    exports.__esModule = true;
    exports.universal = exports.tag = exports.string = exports.selector = exports.root = exports.pseudo = exports.nesting = exports.id = exports.comment = exports.combinator = exports.className = exports.attribute = void 0;
    var _attribute = _interopRequireDefault(require_attribute());
    var _className = _interopRequireDefault(require_className());
    var _combinator = _interopRequireDefault(require_combinator());
    var _comment = _interopRequireDefault(require_comment());
    var _id = _interopRequireDefault(require_id());
    var _nesting = _interopRequireDefault(require_nesting());
    var _pseudo = _interopRequireDefault(require_pseudo());
    var _root = _interopRequireDefault(require_root());
    var _selector = _interopRequireDefault(require_selector());
    var _string = _interopRequireDefault(require_string());
    var _tag = _interopRequireDefault(require_tag());
    var _universal = _interopRequireDefault(require_universal());
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    var attribute = function attribute2(opts) {
      return new _attribute["default"](opts);
    };
    exports.attribute = attribute;
    var className = function className2(opts) {
      return new _className["default"](opts);
    };
    exports.className = className;
    var combinator = function combinator2(opts) {
      return new _combinator["default"](opts);
    };
    exports.combinator = combinator;
    var comment = function comment2(opts) {
      return new _comment["default"](opts);
    };
    exports.comment = comment;
    var id = function id2(opts) {
      return new _id["default"](opts);
    };
    exports.id = id;
    var nesting = function nesting2(opts) {
      return new _nesting["default"](opts);
    };
    exports.nesting = nesting;
    var pseudo = function pseudo2(opts) {
      return new _pseudo["default"](opts);
    };
    exports.pseudo = pseudo;
    var root = function root2(opts) {
      return new _root["default"](opts);
    };
    exports.root = root;
    var selector = function selector2(opts) {
      return new _selector["default"](opts);
    };
    exports.selector = selector;
    var string = function string2(opts) {
      return new _string["default"](opts);
    };
    exports.string = string;
    var tag = function tag2(opts) {
      return new _tag["default"](opts);
    };
    exports.tag = tag;
    var universal = function universal2(opts) {
      return new _universal["default"](opts);
    };
    exports.universal = universal;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/guards.js
var require_guards = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/guards.js"(exports) {
    "use strict";
    exports.__esModule = true;
    exports.isNode = isNode;
    exports.isPseudoElement = isPseudoElement;
    exports.isPseudoClass = isPseudoClass;
    exports.isContainer = isContainer;
    exports.isNamespace = isNamespace;
    exports.isUniversal = exports.isTag = exports.isString = exports.isSelector = exports.isRoot = exports.isPseudo = exports.isNesting = exports.isIdentifier = exports.isComment = exports.isCombinator = exports.isClassName = exports.isAttribute = void 0;
    var _types = require_types();
    var _IS_TYPE;
    var IS_TYPE = (_IS_TYPE = {}, _IS_TYPE[_types.ATTRIBUTE] = true, _IS_TYPE[_types.CLASS] = true, _IS_TYPE[_types.COMBINATOR] = true, _IS_TYPE[_types.COMMENT] = true, _IS_TYPE[_types.ID] = true, _IS_TYPE[_types.NESTING] = true, _IS_TYPE[_types.PSEUDO] = true, _IS_TYPE[_types.ROOT] = true, _IS_TYPE[_types.SELECTOR] = true, _IS_TYPE[_types.STRING] = true, _IS_TYPE[_types.TAG] = true, _IS_TYPE[_types.UNIVERSAL] = true, _IS_TYPE);
    function isNode(node) {
      return typeof node === "object" && IS_TYPE[node.type];
    }
    function isNodeType(type, node) {
      return isNode(node) && node.type === type;
    }
    var isAttribute = isNodeType.bind(null, _types.ATTRIBUTE);
    exports.isAttribute = isAttribute;
    var isClassName = isNodeType.bind(null, _types.CLASS);
    exports.isClassName = isClassName;
    var isCombinator = isNodeType.bind(null, _types.COMBINATOR);
    exports.isCombinator = isCombinator;
    var isComment = isNodeType.bind(null, _types.COMMENT);
    exports.isComment = isComment;
    var isIdentifier = isNodeType.bind(null, _types.ID);
    exports.isIdentifier = isIdentifier;
    var isNesting = isNodeType.bind(null, _types.NESTING);
    exports.isNesting = isNesting;
    var isPseudo = isNodeType.bind(null, _types.PSEUDO);
    exports.isPseudo = isPseudo;
    var isRoot = isNodeType.bind(null, _types.ROOT);
    exports.isRoot = isRoot;
    var isSelector = isNodeType.bind(null, _types.SELECTOR);
    exports.isSelector = isSelector;
    var isString = isNodeType.bind(null, _types.STRING);
    exports.isString = isString;
    var isTag = isNodeType.bind(null, _types.TAG);
    exports.isTag = isTag;
    var isUniversal = isNodeType.bind(null, _types.UNIVERSAL);
    exports.isUniversal = isUniversal;
    function isPseudoElement(node) {
      return isPseudo(node) && node.value && (node.value.startsWith("::") || node.value.toLowerCase() === ":before" || node.value.toLowerCase() === ":after" || node.value.toLowerCase() === ":first-letter" || node.value.toLowerCase() === ":first-line");
    }
    function isPseudoClass(node) {
      return isPseudo(node) && !isPseudoElement(node);
    }
    function isContainer(node) {
      return !!(isNode(node) && node.walk);
    }
    function isNamespace(node) {
      return isAttribute(node) || isTag(node);
    }
  }
});

// node_modules/postcss-selector-parser/dist/selectors/index.js
var require_selectors = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/index.js"(exports) {
    "use strict";
    exports.__esModule = true;
    var _types = require_types();
    Object.keys(_types).forEach(function(key) {
      if (key === "default" || key === "__esModule") return;
      if (key in exports && exports[key] === _types[key]) return;
      exports[key] = _types[key];
    });
    var _constructors = require_constructors();
    Object.keys(_constructors).forEach(function(key) {
      if (key === "default" || key === "__esModule") return;
      if (key in exports && exports[key] === _constructors[key]) return;
      exports[key] = _constructors[key];
    });
    var _guards = require_guards();
    Object.keys(_guards).forEach(function(key) {
      if (key === "default" || key === "__esModule") return;
      if (key in exports && exports[key] === _guards[key]) return;
      exports[key] = _guards[key];
    });
  }
});

// node_modules/postcss-selector-parser/dist/index.js
var require_dist = __commonJS({
  "node_modules/postcss-selector-parser/dist/index.js"(exports, module) {
    "use strict";
    exports.__esModule = true;
    exports["default"] = void 0;
    var _processor = _interopRequireDefault(require_processor());
    var selectors = _interopRequireWildcard(require_selectors());
    function _getRequireWildcardCache() {
      if (typeof WeakMap !== "function") return null;
      var cache = /* @__PURE__ */ new WeakMap();
      _getRequireWildcardCache = function _getRequireWildcardCache2() {
        return cache;
      };
      return cache;
    }
    function _interopRequireWildcard(obj) {
      if (obj && obj.__esModule) {
        return obj;
      }
      if (obj === null || typeof obj !== "object" && typeof obj !== "function") {
        return { "default": obj };
      }
      var cache = _getRequireWildcardCache();
      if (cache && cache.has(obj)) {
        return cache.get(obj);
      }
      var newObj = {};
      var hasPropertyDescriptor = Object.defineProperty && Object.getOwnPropertyDescriptor;
      for (var key in obj) {
        if (Object.prototype.hasOwnProperty.call(obj, key)) {
          var desc = hasPropertyDescriptor ? Object.getOwnPropertyDescriptor(obj, key) : null;
          if (desc && (desc.get || desc.set)) {
            Object.defineProperty(newObj, key, desc);
          } else {
            newObj[key] = obj[key];
          }
        }
      }
      newObj["default"] = obj;
      if (cache) {
        cache.set(obj, newObj);
      }
      return newObj;
    }
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    var parser = function parser2(processor) {
      return new _processor["default"](processor);
    };
    Object.assign(parser, selectors);
    delete parser.__esModule;
    var _default = parser;
    exports["default"] = _default;
    module.exports = exports.default;
  }
});

// node_modules/@tailwindcss/typography/src/utils.js
var require_utils = __commonJS({
  "node_modules/@tailwindcss/typography/src/utils.js"(exports, module) {
    var isPlainObject = require_lodash3();
    var parser = require_dist();
    var parseSelector = parser();
    module.exports = {
      isUsableColor(color, values) {
        return isPlainObject(values) && color !== "gray" && values[600];
      },
      /**
       * @param {string} selector
       */
      commonTrailingPseudos(selector) {
        let ast = parseSelector.astSync(selector);
        let matrix = [];
        for (let [i, sel] of ast.nodes.entries()) {
          for (const [j, child] of [...sel.nodes].reverse().entries()) {
            if (child.type !== "pseudo" || !child.value.startsWith("::")) {
              break;
            }
            matrix[j] = matrix[j] || [];
            matrix[j][i] = child;
          }
        }
        let trailingPseudos = parser.selector();
        for (const pseudos of matrix) {
          if (!pseudos) {
            continue;
          }
          let values = /* @__PURE__ */ new Set([...pseudos.map((p) => p.value)]);
          if (values.size > 1) {
            break;
          }
          pseudos.forEach((pseudo) => pseudo.remove());
          trailingPseudos.prepend(pseudos[0]);
        }
        if (trailingPseudos.nodes.length) {
          return [trailingPseudos.toString(), ast.toString()];
        }
        return [null, selector];
      }
    };
  }
});

// node_modules/@tailwindcss/typography/src/index.js
var require_src2 = __commonJS({
  "node_modules/@tailwindcss/typography/src/index.js"(exports, module) {
    var plugin2 = require_plugin();
    var merge = require_lodash();
    var castArray = require_lodash2();
    var styles = require_styles();
    var { commonTrailingPseudos } = require_utils();
    var computed = {
      // Reserved for future "magic properties", for example:
      // bulletColor: (color) => ({ 'ul > li::before': { backgroundColor: color } }),
    };
    function inWhere(selector, { className, modifier, prefix }) {
      let prefixedNot = prefix(`.not-${className}`).slice(1);
      let selectorPrefix = selector.startsWith(">") ? `${modifier === "DEFAULT" ? `.${className}` : `.${className}-${modifier}`} ` : "";
      let [trailingPseudo, rebuiltSelector] = commonTrailingPseudos(selector);
      if (trailingPseudo) {
        return `:where(${selectorPrefix}${rebuiltSelector}):not(:where([class~="${prefixedNot}"],[class~="${prefixedNot}"] *))${trailingPseudo}`;
      }
      return `:where(${selectorPrefix}${selector}):not(:where([class~="${prefixedNot}"],[class~="${prefixedNot}"] *))`;
    }
    function isObject(value) {
      return typeof value === "object" && value !== null;
    }
    function configToCss(config = {}, { target, className, modifier, prefix }) {
      function updateSelector(k, v) {
        if (target === "legacy") {
          return [k, v];
        }
        if (Array.isArray(v)) {
          return [k, v];
        }
        if (isObject(v)) {
          let nested = Object.values(v).some(isObject);
          if (nested) {
            return [
              inWhere(k, { className, modifier, prefix }),
              v,
              Object.fromEntries(Object.entries(v).map(([k2, v2]) => updateSelector(k2, v2)))
            ];
          }
          return [inWhere(k, { className, modifier, prefix }), v];
        }
        return [k, v];
      }
      return Object.fromEntries(
        Object.entries(
          merge(
            {},
            ...Object.keys(config).filter((key) => computed[key]).map((key) => computed[key](config[key])),
            ...castArray(config.css || {})
          )
        ).map(([k, v]) => updateSelector(k, v))
      );
    }
    module.exports = plugin2.withOptions(
      ({ className = "prose", target = "modern" } = {}) => {
        return function({ addVariant, addComponents, theme, prefix }) {
          let modifiers = theme("typography");
          let options = { className, prefix };
          for (let [name, ...selectors] of [
            ["headings", "h1", "h2", "h3", "h4", "h5", "h6", "th"],
            ["h1"],
            ["h2"],
            ["h3"],
            ["h4"],
            ["h5"],
            ["h6"],
            ["p"],
            ["a"],
            ["blockquote"],
            ["figure"],
            ["figcaption"],
            ["strong"],
            ["em"],
            ["kbd"],
            ["code"],
            ["pre"],
            ["ol"],
            ["ul"],
            ["li"],
            ["table"],
            ["thead"],
            ["tr"],
            ["th"],
            ["td"],
            ["img"],
            ["video"],
            ["hr"],
            ["lead", '[class~="lead"]']
          ]) {
            selectors = selectors.length === 0 ? [name] : selectors;
            let selector = target === "legacy" ? selectors.map((selector2) => `& ${selector2}`) : selectors.join(", ");
            addVariant(
              `${className}-${name}`,
              target === "legacy" ? selector : `& :is(${inWhere(selector, options)})`
            );
          }
          addComponents(
            Object.keys(modifiers).map((modifier) => ({
              [modifier === "DEFAULT" ? `.${className}` : `.${className}-${modifier}`]: configToCss(
                modifiers[modifier],
                {
                  target,
                  className,
                  modifier,
                  prefix
                }
              )
            }))
          );
        };
      },
      () => {
        return {
          theme: { typography: styles }
        };
      }
    );
  }
});

// tailwind.config.js
var plugin = require_plugin();
var tailwind_config_default = {
  content: [],
  theme: {
    extend: {}
  },
  plugins: [
    require_src(),
    require_src2(),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({ addVariant }) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({ addVariant }) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({ addVariant }) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"]))
  ]
};
export {
  tailwind_config_default as default
};
/*! Bundled license information:

cssesc/cssesc.js:
  (*! https://mths.be/cssesc v3.0.0 by @mathias *)
*/
