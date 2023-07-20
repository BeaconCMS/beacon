var BeaconAdmin = (() => {
  // ../deps/live_monaco_editor/priv/static/live_monaco_editor.esm.js
  function _defineProperty(obj, key, value) {
    if (key in obj) {
      Object.defineProperty(obj, key, {
        value,
        enumerable: true,
        configurable: true,
        writable: true
      });
    } else {
      obj[key] = value;
    }
    return obj;
  }
  function ownKeys(object, enumerableOnly) {
    var keys = Object.keys(object);
    if (Object.getOwnPropertySymbols) {
      var symbols = Object.getOwnPropertySymbols(object);
      if (enumerableOnly)
        symbols = symbols.filter(function(sym) {
          return Object.getOwnPropertyDescriptor(object, sym).enumerable;
        });
      keys.push.apply(keys, symbols);
    }
    return keys;
  }
  function _objectSpread2(target) {
    for (var i = 1; i < arguments.length; i++) {
      var source = arguments[i] != null ? arguments[i] : {};
      if (i % 2) {
        ownKeys(Object(source), true).forEach(function(key) {
          _defineProperty(target, key, source[key]);
        });
      } else if (Object.getOwnPropertyDescriptors) {
        Object.defineProperties(target, Object.getOwnPropertyDescriptors(source));
      } else {
        ownKeys(Object(source)).forEach(function(key) {
          Object.defineProperty(target, key, Object.getOwnPropertyDescriptor(source, key));
        });
      }
    }
    return target;
  }
  function _objectWithoutPropertiesLoose(source, excluded) {
    if (source == null)
      return {};
    var target = {};
    var sourceKeys = Object.keys(source);
    var key, i;
    for (i = 0; i < sourceKeys.length; i++) {
      key = sourceKeys[i];
      if (excluded.indexOf(key) >= 0)
        continue;
      target[key] = source[key];
    }
    return target;
  }
  function _objectWithoutProperties(source, excluded) {
    if (source == null)
      return {};
    var target = _objectWithoutPropertiesLoose(source, excluded);
    var key, i;
    if (Object.getOwnPropertySymbols) {
      var sourceSymbolKeys = Object.getOwnPropertySymbols(source);
      for (i = 0; i < sourceSymbolKeys.length; i++) {
        key = sourceSymbolKeys[i];
        if (excluded.indexOf(key) >= 0)
          continue;
        if (!Object.prototype.propertyIsEnumerable.call(source, key))
          continue;
        target[key] = source[key];
      }
    }
    return target;
  }
  function _slicedToArray(arr, i) {
    return _arrayWithHoles(arr) || _iterableToArrayLimit(arr, i) || _unsupportedIterableToArray(arr, i) || _nonIterableRest();
  }
  function _arrayWithHoles(arr) {
    if (Array.isArray(arr))
      return arr;
  }
  function _iterableToArrayLimit(arr, i) {
    if (typeof Symbol === "undefined" || !(Symbol.iterator in Object(arr)))
      return;
    var _arr = [];
    var _n = true;
    var _d = false;
    var _e = void 0;
    try {
      for (var _i = arr[Symbol.iterator](), _s; !(_n = (_s = _i.next()).done); _n = true) {
        _arr.push(_s.value);
        if (i && _arr.length === i)
          break;
      }
    } catch (err) {
      _d = true;
      _e = err;
    } finally {
      try {
        if (!_n && _i["return"] != null)
          _i["return"]();
      } finally {
        if (_d)
          throw _e;
      }
    }
    return _arr;
  }
  function _unsupportedIterableToArray(o, minLen) {
    if (!o)
      return;
    if (typeof o === "string")
      return _arrayLikeToArray(o, minLen);
    var n = Object.prototype.toString.call(o).slice(8, -1);
    if (n === "Object" && o.constructor)
      n = o.constructor.name;
    if (n === "Map" || n === "Set")
      return Array.from(o);
    if (n === "Arguments" || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(n))
      return _arrayLikeToArray(o, minLen);
  }
  function _arrayLikeToArray(arr, len) {
    if (len == null || len > arr.length)
      len = arr.length;
    for (var i = 0, arr2 = new Array(len); i < len; i++)
      arr2[i] = arr[i];
    return arr2;
  }
  function _nonIterableRest() {
    throw new TypeError("Invalid attempt to destructure non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method.");
  }
  function _defineProperty2(obj, key, value) {
    if (key in obj) {
      Object.defineProperty(obj, key, {
        value,
        enumerable: true,
        configurable: true,
        writable: true
      });
    } else {
      obj[key] = value;
    }
    return obj;
  }
  function ownKeys2(object, enumerableOnly) {
    var keys = Object.keys(object);
    if (Object.getOwnPropertySymbols) {
      var symbols = Object.getOwnPropertySymbols(object);
      if (enumerableOnly)
        symbols = symbols.filter(function(sym) {
          return Object.getOwnPropertyDescriptor(object, sym).enumerable;
        });
      keys.push.apply(keys, symbols);
    }
    return keys;
  }
  function _objectSpread22(target) {
    for (var i = 1; i < arguments.length; i++) {
      var source = arguments[i] != null ? arguments[i] : {};
      if (i % 2) {
        ownKeys2(Object(source), true).forEach(function(key) {
          _defineProperty2(target, key, source[key]);
        });
      } else if (Object.getOwnPropertyDescriptors) {
        Object.defineProperties(target, Object.getOwnPropertyDescriptors(source));
      } else {
        ownKeys2(Object(source)).forEach(function(key) {
          Object.defineProperty(target, key, Object.getOwnPropertyDescriptor(source, key));
        });
      }
    }
    return target;
  }
  function compose() {
    for (var _len = arguments.length, fns = new Array(_len), _key = 0; _key < _len; _key++) {
      fns[_key] = arguments[_key];
    }
    return function(x) {
      return fns.reduceRight(function(y, f) {
        return f(y);
      }, x);
    };
  }
  function curry(fn) {
    return function curried() {
      var _this = this;
      for (var _len2 = arguments.length, args = new Array(_len2), _key2 = 0; _key2 < _len2; _key2++) {
        args[_key2] = arguments[_key2];
      }
      return args.length >= fn.length ? fn.apply(this, args) : function() {
        for (var _len3 = arguments.length, nextArgs = new Array(_len3), _key3 = 0; _key3 < _len3; _key3++) {
          nextArgs[_key3] = arguments[_key3];
        }
        return curried.apply(_this, [].concat(args, nextArgs));
      };
    };
  }
  function isObject(value) {
    return {}.toString.call(value).includes("Object");
  }
  function isEmpty(obj) {
    return !Object.keys(obj).length;
  }
  function isFunction(value) {
    return typeof value === "function";
  }
  function hasOwnProperty(object, property) {
    return Object.prototype.hasOwnProperty.call(object, property);
  }
  function validateChanges(initial, changes) {
    if (!isObject(changes))
      errorHandler("changeType");
    if (Object.keys(changes).some(function(field) {
      return !hasOwnProperty(initial, field);
    }))
      errorHandler("changeField");
    return changes;
  }
  function validateSelector(selector) {
    if (!isFunction(selector))
      errorHandler("selectorType");
  }
  function validateHandler(handler) {
    if (!(isFunction(handler) || isObject(handler)))
      errorHandler("handlerType");
    if (isObject(handler) && Object.values(handler).some(function(_handler) {
      return !isFunction(_handler);
    }))
      errorHandler("handlersType");
  }
  function validateInitial(initial) {
    if (!initial)
      errorHandler("initialIsRequired");
    if (!isObject(initial))
      errorHandler("initialType");
    if (isEmpty(initial))
      errorHandler("initialContent");
  }
  function throwError(errorMessages3, type) {
    throw new Error(errorMessages3[type] || errorMessages3["default"]);
  }
  var errorMessages = {
    initialIsRequired: "initial state is required",
    initialType: "initial state should be an object",
    initialContent: "initial state shouldn't be an empty object",
    handlerType: "handler should be an object or a function",
    handlersType: "all handlers should be a functions",
    selectorType: "selector should be a function",
    changeType: "provided value of changes should be an object",
    changeField: 'it seams you want to change a field in the state which is not specified in the "initial" state',
    "default": "an unknown error accured in `state-local` package"
  };
  var errorHandler = curry(throwError)(errorMessages);
  var validators = {
    changes: validateChanges,
    selector: validateSelector,
    handler: validateHandler,
    initial: validateInitial
  };
  function create(initial) {
    var handler = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : {};
    validators.initial(initial);
    validators.handler(handler);
    var state = {
      current: initial
    };
    var didUpdate = curry(didStateUpdate)(state, handler);
    var update = curry(updateState)(state);
    var validate = curry(validators.changes)(initial);
    var getChanges = curry(extractChanges)(state);
    function getState2() {
      var selector = arguments.length > 0 && arguments[0] !== void 0 ? arguments[0] : function(state2) {
        return state2;
      };
      validators.selector(selector);
      return selector(state.current);
    }
    function setState2(causedChanges) {
      compose(didUpdate, update, validate, getChanges)(causedChanges);
    }
    return [getState2, setState2];
  }
  function extractChanges(state, causedChanges) {
    return isFunction(causedChanges) ? causedChanges(state.current) : causedChanges;
  }
  function updateState(state, changes) {
    state.current = _objectSpread22(_objectSpread22({}, state.current), changes);
    return changes;
  }
  function didStateUpdate(state, handler, changes) {
    isFunction(handler) ? handler(state.current) : Object.keys(changes).forEach(function(field) {
      var _handler$field;
      return (_handler$field = handler[field]) === null || _handler$field === void 0 ? void 0 : _handler$field.call(handler, state.current[field]);
    });
    return changes;
  }
  var index = {
    create
  };
  var state_local_default = index;
  var config = {
    paths: {
      vs: "https://cdn.jsdelivr.net/npm/monaco-editor@0.36.1/min/vs"
    }
  };
  var config_default = config;
  function curry2(fn) {
    return function curried() {
      var _this = this;
      for (var _len = arguments.length, args = new Array(_len), _key = 0; _key < _len; _key++) {
        args[_key] = arguments[_key];
      }
      return args.length >= fn.length ? fn.apply(this, args) : function() {
        for (var _len2 = arguments.length, nextArgs = new Array(_len2), _key2 = 0; _key2 < _len2; _key2++) {
          nextArgs[_key2] = arguments[_key2];
        }
        return curried.apply(_this, [].concat(args, nextArgs));
      };
    };
  }
  var curry_default = curry2;
  function isObject2(value) {
    return {}.toString.call(value).includes("Object");
  }
  var isObject_default = isObject2;
  function validateConfig(config3) {
    if (!config3)
      errorHandler2("configIsRequired");
    if (!isObject_default(config3))
      errorHandler2("configType");
    if (config3.urls) {
      informAboutDeprecation();
      return {
        paths: {
          vs: config3.urls.monacoBase
        }
      };
    }
    return config3;
  }
  function informAboutDeprecation() {
    console.warn(errorMessages2.deprecation);
  }
  function throwError2(errorMessages3, type) {
    throw new Error(errorMessages3[type] || errorMessages3["default"]);
  }
  var errorMessages2 = {
    configIsRequired: "the configuration object is required",
    configType: "the configuration object should be an object",
    "default": "an unknown error accured in `@monaco-editor/loader` package",
    deprecation: "Deprecation warning!\n    You are using deprecated way of configuration.\n\n    Instead of using\n      monaco.config({ urls: { monacoBase: '...' } })\n    use\n      monaco.config({ paths: { vs: '...' } })\n\n    For more please check the link https://github.com/suren-atoyan/monaco-loader#config\n  "
  };
  var errorHandler2 = curry_default(throwError2)(errorMessages2);
  var validators2 = {
    config: validateConfig
  };
  var validators_default = validators2;
  var compose2 = function compose3() {
    for (var _len = arguments.length, fns = new Array(_len), _key = 0; _key < _len; _key++) {
      fns[_key] = arguments[_key];
    }
    return function(x) {
      return fns.reduceRight(function(y, f) {
        return f(y);
      }, x);
    };
  };
  var compose_default = compose2;
  function merge(target, source) {
    Object.keys(source).forEach(function(key) {
      if (source[key] instanceof Object) {
        if (target[key]) {
          Object.assign(source[key], merge(target[key], source[key]));
        }
      }
    });
    return _objectSpread2(_objectSpread2({}, target), source);
  }
  var deepMerge_default = merge;
  var CANCELATION_MESSAGE = {
    type: "cancelation",
    msg: "operation is manually canceled"
  };
  function makeCancelable(promise) {
    var hasCanceled_ = false;
    var wrappedPromise = new Promise(function(resolve, reject) {
      promise.then(function(val) {
        return hasCanceled_ ? reject(CANCELATION_MESSAGE) : resolve(val);
      });
      promise["catch"](reject);
    });
    return wrappedPromise.cancel = function() {
      return hasCanceled_ = true;
    }, wrappedPromise;
  }
  var makeCancelable_default = makeCancelable;
  var _state$create = state_local_default.create({
    config: config_default,
    isInitialized: false,
    resolve: null,
    reject: null,
    monaco: null
  });
  var _state$create2 = _slicedToArray(_state$create, 2);
  var getState = _state$create2[0];
  var setState = _state$create2[1];
  function config2(globalConfig) {
    var _validators$config = validators_default.config(globalConfig), monaco = _validators$config.monaco, config3 = _objectWithoutProperties(_validators$config, ["monaco"]);
    setState(function(state) {
      return {
        config: deepMerge_default(state.config, config3),
        monaco
      };
    });
  }
  function init() {
    var state = getState(function(_ref) {
      var monaco = _ref.monaco, isInitialized = _ref.isInitialized, resolve = _ref.resolve;
      return {
        monaco,
        isInitialized,
        resolve
      };
    });
    if (!state.isInitialized) {
      setState({
        isInitialized: true
      });
      if (state.monaco) {
        state.resolve(state.monaco);
        return makeCancelable_default(wrapperPromise);
      }
      if (window.monaco && window.monaco.editor) {
        storeMonacoInstance(window.monaco);
        state.resolve(window.monaco);
        return makeCancelable_default(wrapperPromise);
      }
      compose_default(injectScripts, getMonacoLoaderScript)(configureLoader);
    }
    return makeCancelable_default(wrapperPromise);
  }
  function injectScripts(script) {
    return document.body.appendChild(script);
  }
  function createScript(src) {
    var script = document.createElement("script");
    return src && (script.src = src), script;
  }
  function getMonacoLoaderScript(configureLoader2) {
    var state = getState(function(_ref2) {
      var config3 = _ref2.config, reject = _ref2.reject;
      return {
        config: config3,
        reject
      };
    });
    var loaderScript = createScript("".concat(state.config.paths.vs, "/loader.js"));
    loaderScript.onload = function() {
      return configureLoader2();
    };
    loaderScript.onerror = state.reject;
    return loaderScript;
  }
  function configureLoader() {
    var state = getState(function(_ref3) {
      var config3 = _ref3.config, resolve = _ref3.resolve, reject = _ref3.reject;
      return {
        config: config3,
        resolve,
        reject
      };
    });
    var require2 = window.require;
    require2.config(state.config);
    require2(["vs/editor/editor.main"], function(monaco) {
      storeMonacoInstance(monaco);
      state.resolve(monaco);
    }, function(error) {
      state.reject(error);
    });
  }
  function storeMonacoInstance(monaco) {
    if (!getState().monaco) {
      setState({
        monaco
      });
    }
  }
  function __getMonacoInstance() {
    return getState(function(_ref4) {
      var monaco = _ref4.monaco;
      return monaco;
    });
  }
  var wrapperPromise = new Promise(function(resolve, reject) {
    return setState({
      resolve,
      reject
    });
  });
  var loader = {
    config: config2,
    init,
    __getMonacoInstance
  };
  var loader_default = loader;
  var colors = {
    background: "#282c34",
    default: "#c4cad6",
    lightRed: "#e06c75",
    blue: "#61afef",
    gray: "#8c92a3",
    green: "#98c379",
    purple: "#c678dd",
    red: "#be5046",
    teal: "#56b6c2",
    peach: "#d19a66"
  };
  var rules = (colors2) => [
    { token: "", foreground: colors2.default },
    { token: "variable", foreground: colors2.lightRed },
    { token: "constant", foreground: colors2.blue },
    { token: "constant.character.escape", foreground: colors2.blue },
    { token: "comment", foreground: colors2.gray },
    { token: "number", foreground: colors2.blue },
    { token: "regexp", foreground: colors2.lightRed },
    { token: "type", foreground: colors2.lightRed },
    { token: "string", foreground: colors2.green },
    { token: "keyword", foreground: colors2.purple },
    { token: "operator", foreground: colors2.peach },
    { token: "delimiter.bracket.embed", foreground: colors2.red },
    { token: "sigil", foreground: colors2.teal },
    { token: "function", foreground: colors2.blue },
    { token: "function.call", foreground: colors2.default },
    // Markdown specific
    { token: "emphasis", fontStyle: "italic" },
    { token: "strong", fontStyle: "bold" },
    { token: "keyword.md", foreground: colors2.lightRed },
    { token: "keyword.table", foreground: colors2.lightRed },
    { token: "string.link.md", foreground: colors2.blue },
    { token: "variable.md", foreground: colors2.teal },
    { token: "string.md", foreground: colors2.default },
    { token: "variable.source.md", foreground: colors2.default },
    // XML specific
    { token: "tag", foreground: colors2.lightRed },
    { token: "metatag", foreground: colors2.lightRed },
    { token: "attribute.name", foreground: colors2.peach },
    { token: "attribute.value", foreground: colors2.green },
    // JSON specific
    { token: "string.key", foreground: colors2.lightRed },
    { token: "keyword.json", foreground: colors2.blue },
    // SQL specific
    { token: "operator.sql", foreground: colors2.purple }
  ];
  var theme = {
    base: "vs-dark",
    inherit: false,
    rules: rules(colors),
    colors: {
      "editor.background": colors.background,
      "editor.foreground": colors.default,
      "editorLineNumber.foreground": "#636d83",
      "editorCursor.foreground": "#636d83",
      "editor.selectionBackground": "#3e4451",
      "editor.findMatchHighlightBackground": "#528bff3d",
      "editorSuggestWidget.background": "#21252b",
      "editorSuggestWidget.border": "#181a1f",
      "editorSuggestWidget.selectedBackground": "#2c313a",
      "input.background": "#1b1d23",
      "input.border": "#181a1f",
      "editorBracketMatch.border": "#282c34",
      "editorBracketMatch.background": "#3e4451"
    }
  };
  var CodeEditor = class {
    constructor(el, path, value, opts) {
      this.el = el;
      this.path = path;
      this.value = value;
      this.opts = opts;
      this.standalone_code_editor = null;
      this._onMount = [];
    }
    isMounted() {
      return !!this.standalone_code_editor;
    }
    mount() {
      if (this.isMounted()) {
        throw new Error("The monaco editor is already mounted");
      }
      this._mountEditor();
    }
    onMount(callback) {
      this._onMount.push(callback);
    }
    dispose() {
      if (this.isMounted()) {
        const model = this.standalone_code_editor.getModel();
        if (model) {
          model.dispose();
        }
        this.standalone_code_editor.dispose();
      }
    }
    _mountEditor() {
      this.opts.value = this.value;
      loader_default.init().then((monaco) => {
        monaco.editor.defineTheme("default", theme);
        let modelUri = monaco.Uri.parse(this.path);
        let language = this.opts.language;
        let model = monaco.editor.createModel(this.value, language, modelUri);
        this.opts.language = void 0;
        this.opts.model = model;
        this.standalone_code_editor = monaco.editor.create(this.el, this.opts);
        this._onMount.forEach((callback) => callback(monaco));
      });
    }
  };
  var code_editor_default = CodeEditor;
  var CodeEditorHook = {
    mounted() {
      const opts = JSON.parse(this.el.dataset.opts);
      this.codeEditor = new code_editor_default(
        this.el,
        this.el.dataset.path,
        this.el.dataset.value,
        opts
      );
      this.codeEditor.onMount((monaco) => {
        this.el.dispatchEvent(
          new CustomEvent("lme:editor_mounted", {
            detail: { hook: this, editor: this.codeEditor },
            bubbles: true
          })
        );
        this.handleEvent(
          "lme:change_language:" + this.el.dataset.path,
          (data) => {
            const model = this.codeEditor.standalone_code_editor.getModel();
            if (model.getLanguageId() !== data.mimeTypeOrLanguageId) {
              monaco.editor.setModelLanguage(model, data.mimeTypeOrLanguageId);
            }
          }
        );
        this.handleEvent("lme:set_value:" + this.el.dataset.path, (data) => {
          this.codeEditor.standalone_code_editor.setValue(data.value);
        });
        this.el.querySelectorAll("textarea").forEach((textarea) => {
          textarea.setAttribute(
            "name",
            "live_monaco_editor[" + this.el.dataset.path + "]"
          );
        });
        this.el.removeAttribute("data-value");
        this.el.removeAttribute("data-opts");
      });
      if (!this.codeEditor.isMounted()) {
        this.codeEditor.mount();
      }
    },
    destroyed() {
      if (this.codeEditor) {
        this.codeEditor.dispose();
      }
    }
  };

  // js/beacon_admin.js
  var Hooks = {};
  Hooks.CodeEditorHook = CodeEditorHook;
  window.addEventListener("lme:editor_mounted", (ev) => {
    const hook = ev.detail.hook;
    const editor = ev.detail.editor.standalone_code_editor;
    const eventName = ev.detail.editor.path + "_editor_lost_focus";
    editor.onDidBlurEditorWidget(() => {
      hook.pushEvent(eventName, { value: editor.getValue() });
    });
  });
  window.addEventListener("beacon_admin:clipcopy", (event) => {
    const result_id = `${event.target.id}-copy-to-clipboard-result`;
    const el = document.getElementById(result_id);
    if ("clipboard" in navigator) {
      if (event.target.tagName === "INPUT") {
        txt = event.target.value;
      } else {
        txt = event.target.textContent;
      }
      navigator.clipboard.writeText(txt).then(() => {
        el.innerText = "Copied to clipboard";
        el.classList.remove("invisible", "text-red-500", "opacity-0");
        el.classList.add("text-green-500", "opacity-100", "-translate-y-2");
        setTimeout(function() {
          el.classList.remove("text-green-500", "opacity-100", "-translate-y-2");
          el.classList.add("invisible", "text-red-500", "opacity-0");
        }, 2e3);
      }).catch(() => {
        el.innerText = "Could not copy";
        el.classList.remove("invisible", "text-green-500", "opacity-0");
        el.classList.add("text-red-500", "opacity-100", "-translate-y-2");
      });
    } else {
      alert(
        "Sorry, your browser does not support clipboard copy."
      );
    }
  });
  var socketPath = document.querySelector("html").getAttribute("phx-socket") || "/live";
  var csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
  var liveSocket = new LiveView.LiveSocket(socketPath, Phoenix.Socket, {
    hooks: Hooks,
    params: { _csrf_token: csrfToken }
  });
  liveSocket.connect();
  window.liveSocket = liveSocket;
})();
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsiLi4vLi4vZGVwcy9saXZlX21vbmFjb19lZGl0b3IvYXNzZXRzL25vZGVfbW9kdWxlcy9AbW9uYWNvLWVkaXRvci9sb2FkZXIvbGliL2VzL192aXJ0dWFsL19yb2xsdXBQbHVnaW5CYWJlbEhlbHBlcnMuanMiLCAiLi4vLi4vZGVwcy9saXZlX21vbmFjb19lZGl0b3IvYXNzZXRzL25vZGVfbW9kdWxlcy9zdGF0ZS1sb2NhbC9saWIvZXMvc3RhdGUtbG9jYWwuanMiLCAiLi4vLi4vZGVwcy9saXZlX21vbmFjb19lZGl0b3IvYXNzZXRzL25vZGVfbW9kdWxlcy9AbW9uYWNvLWVkaXRvci9sb2FkZXIvbGliL2VzL2NvbmZpZy9pbmRleC5qcyIsICIuLi8uLi9kZXBzL2xpdmVfbW9uYWNvX2VkaXRvci9hc3NldHMvbm9kZV9tb2R1bGVzL0Btb25hY28tZWRpdG9yL2xvYWRlci9saWIvZXMvdXRpbHMvY3VycnkuanMiLCAiLi4vLi4vZGVwcy9saXZlX21vbmFjb19lZGl0b3IvYXNzZXRzL25vZGVfbW9kdWxlcy9AbW9uYWNvLWVkaXRvci9sb2FkZXIvbGliL2VzL3V0aWxzL2lzT2JqZWN0LmpzIiwgIi4uLy4uL2RlcHMvbGl2ZV9tb25hY29fZWRpdG9yL2Fzc2V0cy9ub2RlX21vZHVsZXMvQG1vbmFjby1lZGl0b3IvbG9hZGVyL2xpYi9lcy92YWxpZGF0b3JzL2luZGV4LmpzIiwgIi4uLy4uL2RlcHMvbGl2ZV9tb25hY29fZWRpdG9yL2Fzc2V0cy9ub2RlX21vZHVsZXMvQG1vbmFjby1lZGl0b3IvbG9hZGVyL2xpYi9lcy91dGlscy9jb21wb3NlLmpzIiwgIi4uLy4uL2RlcHMvbGl2ZV9tb25hY29fZWRpdG9yL2Fzc2V0cy9ub2RlX21vZHVsZXMvQG1vbmFjby1lZGl0b3IvbG9hZGVyL2xpYi9lcy91dGlscy9kZWVwTWVyZ2UuanMiLCAiLi4vLi4vZGVwcy9saXZlX21vbmFjb19lZGl0b3IvYXNzZXRzL25vZGVfbW9kdWxlcy9AbW9uYWNvLWVkaXRvci9sb2FkZXIvbGliL2VzL3V0aWxzL21ha2VDYW5jZWxhYmxlLmpzIiwgIi4uLy4uL2RlcHMvbGl2ZV9tb25hY29fZWRpdG9yL2Fzc2V0cy9ub2RlX21vZHVsZXMvQG1vbmFjby1lZGl0b3IvbG9hZGVyL2xpYi9lcy9sb2FkZXIvaW5kZXguanMiLCAiLi4vLi4vZGVwcy9saXZlX21vbmFjb19lZGl0b3IvYXNzZXRzL2pzL2xpdmVfbW9uYWNvX2VkaXRvci9lZGl0b3IvdGhlbWVzLmpzIiwgIi4uLy4uL2RlcHMvbGl2ZV9tb25hY29fZWRpdG9yL2Fzc2V0cy9qcy9saXZlX21vbmFjb19lZGl0b3IvZWRpdG9yL2NvZGVfZWRpdG9yLmpzIiwgIi4uLy4uL2RlcHMvbGl2ZV9tb25hY29fZWRpdG9yL2Fzc2V0cy9qcy9saXZlX21vbmFjb19lZGl0b3IvaG9va3MvY29kZV9lZGl0b3IuanMiLCAiLi4vLi4vYXNzZXRzL2pzL2JlYWNvbl9hZG1pbi5qcyJdLAogICJzb3VyY2VzQ29udGVudCI6IFsiZnVuY3Rpb24gX2RlZmluZVByb3BlcnR5KG9iaiwga2V5LCB2YWx1ZSkge1xuICBpZiAoa2V5IGluIG9iaikge1xuICAgIE9iamVjdC5kZWZpbmVQcm9wZXJ0eShvYmosIGtleSwge1xuICAgICAgdmFsdWU6IHZhbHVlLFxuICAgICAgZW51bWVyYWJsZTogdHJ1ZSxcbiAgICAgIGNvbmZpZ3VyYWJsZTogdHJ1ZSxcbiAgICAgIHdyaXRhYmxlOiB0cnVlXG4gICAgfSk7XG4gIH0gZWxzZSB7XG4gICAgb2JqW2tleV0gPSB2YWx1ZTtcbiAgfVxuXG4gIHJldHVybiBvYmo7XG59XG5cbmZ1bmN0aW9uIG93bktleXMob2JqZWN0LCBlbnVtZXJhYmxlT25seSkge1xuICB2YXIga2V5cyA9IE9iamVjdC5rZXlzKG9iamVjdCk7XG5cbiAgaWYgKE9iamVjdC5nZXRPd25Qcm9wZXJ0eVN5bWJvbHMpIHtcbiAgICB2YXIgc3ltYm9scyA9IE9iamVjdC5nZXRPd25Qcm9wZXJ0eVN5bWJvbHMob2JqZWN0KTtcbiAgICBpZiAoZW51bWVyYWJsZU9ubHkpIHN5bWJvbHMgPSBzeW1ib2xzLmZpbHRlcihmdW5jdGlvbiAoc3ltKSB7XG4gICAgICByZXR1cm4gT2JqZWN0LmdldE93blByb3BlcnR5RGVzY3JpcHRvcihvYmplY3QsIHN5bSkuZW51bWVyYWJsZTtcbiAgICB9KTtcbiAgICBrZXlzLnB1c2guYXBwbHkoa2V5cywgc3ltYm9scyk7XG4gIH1cblxuICByZXR1cm4ga2V5cztcbn1cblxuZnVuY3Rpb24gX29iamVjdFNwcmVhZDIodGFyZ2V0KSB7XG4gIGZvciAodmFyIGkgPSAxOyBpIDwgYXJndW1lbnRzLmxlbmd0aDsgaSsrKSB7XG4gICAgdmFyIHNvdXJjZSA9IGFyZ3VtZW50c1tpXSAhPSBudWxsID8gYXJndW1lbnRzW2ldIDoge307XG5cbiAgICBpZiAoaSAlIDIpIHtcbiAgICAgIG93bktleXMoT2JqZWN0KHNvdXJjZSksIHRydWUpLmZvckVhY2goZnVuY3Rpb24gKGtleSkge1xuICAgICAgICBfZGVmaW5lUHJvcGVydHkodGFyZ2V0LCBrZXksIHNvdXJjZVtrZXldKTtcbiAgICAgIH0pO1xuICAgIH0gZWxzZSBpZiAoT2JqZWN0LmdldE93blByb3BlcnR5RGVzY3JpcHRvcnMpIHtcbiAgICAgIE9iamVjdC5kZWZpbmVQcm9wZXJ0aWVzKHRhcmdldCwgT2JqZWN0LmdldE93blByb3BlcnR5RGVzY3JpcHRvcnMoc291cmNlKSk7XG4gICAgfSBlbHNlIHtcbiAgICAgIG93bktleXMoT2JqZWN0KHNvdXJjZSkpLmZvckVhY2goZnVuY3Rpb24gKGtleSkge1xuICAgICAgICBPYmplY3QuZGVmaW5lUHJvcGVydHkodGFyZ2V0LCBrZXksIE9iamVjdC5nZXRPd25Qcm9wZXJ0eURlc2NyaXB0b3Ioc291cmNlLCBrZXkpKTtcbiAgICAgIH0pO1xuICAgIH1cbiAgfVxuXG4gIHJldHVybiB0YXJnZXQ7XG59XG5cbmZ1bmN0aW9uIF9vYmplY3RXaXRob3V0UHJvcGVydGllc0xvb3NlKHNvdXJjZSwgZXhjbHVkZWQpIHtcbiAgaWYgKHNvdXJjZSA9PSBudWxsKSByZXR1cm4ge307XG4gIHZhciB0YXJnZXQgPSB7fTtcbiAgdmFyIHNvdXJjZUtleXMgPSBPYmplY3Qua2V5cyhzb3VyY2UpO1xuICB2YXIga2V5LCBpO1xuXG4gIGZvciAoaSA9IDA7IGkgPCBzb3VyY2VLZXlzLmxlbmd0aDsgaSsrKSB7XG4gICAga2V5ID0gc291cmNlS2V5c1tpXTtcbiAgICBpZiAoZXhjbHVkZWQuaW5kZXhPZihrZXkpID49IDApIGNvbnRpbnVlO1xuICAgIHRhcmdldFtrZXldID0gc291cmNlW2tleV07XG4gIH1cblxuICByZXR1cm4gdGFyZ2V0O1xufVxuXG5mdW5jdGlvbiBfb2JqZWN0V2l0aG91dFByb3BlcnRpZXMoc291cmNlLCBleGNsdWRlZCkge1xuICBpZiAoc291cmNlID09IG51bGwpIHJldHVybiB7fTtcblxuICB2YXIgdGFyZ2V0ID0gX29iamVjdFdpdGhvdXRQcm9wZXJ0aWVzTG9vc2Uoc291cmNlLCBleGNsdWRlZCk7XG5cbiAgdmFyIGtleSwgaTtcblxuICBpZiAoT2JqZWN0LmdldE93blByb3BlcnR5U3ltYm9scykge1xuICAgIHZhciBzb3VyY2VTeW1ib2xLZXlzID0gT2JqZWN0LmdldE93blByb3BlcnR5U3ltYm9scyhzb3VyY2UpO1xuXG4gICAgZm9yIChpID0gMDsgaSA8IHNvdXJjZVN5bWJvbEtleXMubGVuZ3RoOyBpKyspIHtcbiAgICAgIGtleSA9IHNvdXJjZVN5bWJvbEtleXNbaV07XG4gICAgICBpZiAoZXhjbHVkZWQuaW5kZXhPZihrZXkpID49IDApIGNvbnRpbnVlO1xuICAgICAgaWYgKCFPYmplY3QucHJvdG90eXBlLnByb3BlcnR5SXNFbnVtZXJhYmxlLmNhbGwoc291cmNlLCBrZXkpKSBjb250aW51ZTtcbiAgICAgIHRhcmdldFtrZXldID0gc291cmNlW2tleV07XG4gICAgfVxuICB9XG5cbiAgcmV0dXJuIHRhcmdldDtcbn1cblxuZnVuY3Rpb24gX3NsaWNlZFRvQXJyYXkoYXJyLCBpKSB7XG4gIHJldHVybiBfYXJyYXlXaXRoSG9sZXMoYXJyKSB8fCBfaXRlcmFibGVUb0FycmF5TGltaXQoYXJyLCBpKSB8fCBfdW5zdXBwb3J0ZWRJdGVyYWJsZVRvQXJyYXkoYXJyLCBpKSB8fCBfbm9uSXRlcmFibGVSZXN0KCk7XG59XG5cbmZ1bmN0aW9uIF9hcnJheVdpdGhIb2xlcyhhcnIpIHtcbiAgaWYgKEFycmF5LmlzQXJyYXkoYXJyKSkgcmV0dXJuIGFycjtcbn1cblxuZnVuY3Rpb24gX2l0ZXJhYmxlVG9BcnJheUxpbWl0KGFyciwgaSkge1xuICBpZiAodHlwZW9mIFN5bWJvbCA9PT0gXCJ1bmRlZmluZWRcIiB8fCAhKFN5bWJvbC5pdGVyYXRvciBpbiBPYmplY3QoYXJyKSkpIHJldHVybjtcbiAgdmFyIF9hcnIgPSBbXTtcbiAgdmFyIF9uID0gdHJ1ZTtcbiAgdmFyIF9kID0gZmFsc2U7XG4gIHZhciBfZSA9IHVuZGVmaW5lZDtcblxuICB0cnkge1xuICAgIGZvciAodmFyIF9pID0gYXJyW1N5bWJvbC5pdGVyYXRvcl0oKSwgX3M7ICEoX24gPSAoX3MgPSBfaS5uZXh0KCkpLmRvbmUpOyBfbiA9IHRydWUpIHtcbiAgICAgIF9hcnIucHVzaChfcy52YWx1ZSk7XG5cbiAgICAgIGlmIChpICYmIF9hcnIubGVuZ3RoID09PSBpKSBicmVhaztcbiAgICB9XG4gIH0gY2F0Y2ggKGVycikge1xuICAgIF9kID0gdHJ1ZTtcbiAgICBfZSA9IGVycjtcbiAgfSBmaW5hbGx5IHtcbiAgICB0cnkge1xuICAgICAgaWYgKCFfbiAmJiBfaVtcInJldHVyblwiXSAhPSBudWxsKSBfaVtcInJldHVyblwiXSgpO1xuICAgIH0gZmluYWxseSB7XG4gICAgICBpZiAoX2QpIHRocm93IF9lO1xuICAgIH1cbiAgfVxuXG4gIHJldHVybiBfYXJyO1xufVxuXG5mdW5jdGlvbiBfdW5zdXBwb3J0ZWRJdGVyYWJsZVRvQXJyYXkobywgbWluTGVuKSB7XG4gIGlmICghbykgcmV0dXJuO1xuICBpZiAodHlwZW9mIG8gPT09IFwic3RyaW5nXCIpIHJldHVybiBfYXJyYXlMaWtlVG9BcnJheShvLCBtaW5MZW4pO1xuICB2YXIgbiA9IE9iamVjdC5wcm90b3R5cGUudG9TdHJpbmcuY2FsbChvKS5zbGljZSg4LCAtMSk7XG4gIGlmIChuID09PSBcIk9iamVjdFwiICYmIG8uY29uc3RydWN0b3IpIG4gPSBvLmNvbnN0cnVjdG9yLm5hbWU7XG4gIGlmIChuID09PSBcIk1hcFwiIHx8IG4gPT09IFwiU2V0XCIpIHJldHVybiBBcnJheS5mcm9tKG8pO1xuICBpZiAobiA9PT0gXCJBcmd1bWVudHNcIiB8fCAvXig/OlVpfEkpbnQoPzo4fDE2fDMyKSg/OkNsYW1wZWQpP0FycmF5JC8udGVzdChuKSkgcmV0dXJuIF9hcnJheUxpa2VUb0FycmF5KG8sIG1pbkxlbik7XG59XG5cbmZ1bmN0aW9uIF9hcnJheUxpa2VUb0FycmF5KGFyciwgbGVuKSB7XG4gIGlmIChsZW4gPT0gbnVsbCB8fCBsZW4gPiBhcnIubGVuZ3RoKSBsZW4gPSBhcnIubGVuZ3RoO1xuXG4gIGZvciAodmFyIGkgPSAwLCBhcnIyID0gbmV3IEFycmF5KGxlbik7IGkgPCBsZW47IGkrKykgYXJyMltpXSA9IGFycltpXTtcblxuICByZXR1cm4gYXJyMjtcbn1cblxuZnVuY3Rpb24gX25vbkl0ZXJhYmxlUmVzdCgpIHtcbiAgdGhyb3cgbmV3IFR5cGVFcnJvcihcIkludmFsaWQgYXR0ZW1wdCB0byBkZXN0cnVjdHVyZSBub24taXRlcmFibGUgaW5zdGFuY2UuXFxuSW4gb3JkZXIgdG8gYmUgaXRlcmFibGUsIG5vbi1hcnJheSBvYmplY3RzIG11c3QgaGF2ZSBhIFtTeW1ib2wuaXRlcmF0b3JdKCkgbWV0aG9kLlwiKTtcbn1cblxuZXhwb3J0IHsgX2FycmF5TGlrZVRvQXJyYXkgYXMgYXJyYXlMaWtlVG9BcnJheSwgX2FycmF5V2l0aEhvbGVzIGFzIGFycmF5V2l0aEhvbGVzLCBfZGVmaW5lUHJvcGVydHkgYXMgZGVmaW5lUHJvcGVydHksIF9pdGVyYWJsZVRvQXJyYXlMaW1pdCBhcyBpdGVyYWJsZVRvQXJyYXlMaW1pdCwgX25vbkl0ZXJhYmxlUmVzdCBhcyBub25JdGVyYWJsZVJlc3QsIF9vYmplY3RTcHJlYWQyIGFzIG9iamVjdFNwcmVhZDIsIF9vYmplY3RXaXRob3V0UHJvcGVydGllcyBhcyBvYmplY3RXaXRob3V0UHJvcGVydGllcywgX29iamVjdFdpdGhvdXRQcm9wZXJ0aWVzTG9vc2UgYXMgb2JqZWN0V2l0aG91dFByb3BlcnRpZXNMb29zZSwgX3NsaWNlZFRvQXJyYXkgYXMgc2xpY2VkVG9BcnJheSwgX3Vuc3VwcG9ydGVkSXRlcmFibGVUb0FycmF5IGFzIHVuc3VwcG9ydGVkSXRlcmFibGVUb0FycmF5IH07XG4iLCAiZnVuY3Rpb24gX2RlZmluZVByb3BlcnR5KG9iaiwga2V5LCB2YWx1ZSkge1xuICBpZiAoa2V5IGluIG9iaikge1xuICAgIE9iamVjdC5kZWZpbmVQcm9wZXJ0eShvYmosIGtleSwge1xuICAgICAgdmFsdWU6IHZhbHVlLFxuICAgICAgZW51bWVyYWJsZTogdHJ1ZSxcbiAgICAgIGNvbmZpZ3VyYWJsZTogdHJ1ZSxcbiAgICAgIHdyaXRhYmxlOiB0cnVlXG4gICAgfSk7XG4gIH0gZWxzZSB7XG4gICAgb2JqW2tleV0gPSB2YWx1ZTtcbiAgfVxuXG4gIHJldHVybiBvYmo7XG59XG5cbmZ1bmN0aW9uIG93bktleXMob2JqZWN0LCBlbnVtZXJhYmxlT25seSkge1xuICB2YXIga2V5cyA9IE9iamVjdC5rZXlzKG9iamVjdCk7XG5cbiAgaWYgKE9iamVjdC5nZXRPd25Qcm9wZXJ0eVN5bWJvbHMpIHtcbiAgICB2YXIgc3ltYm9scyA9IE9iamVjdC5nZXRPd25Qcm9wZXJ0eVN5bWJvbHMob2JqZWN0KTtcbiAgICBpZiAoZW51bWVyYWJsZU9ubHkpIHN5bWJvbHMgPSBzeW1ib2xzLmZpbHRlcihmdW5jdGlvbiAoc3ltKSB7XG4gICAgICByZXR1cm4gT2JqZWN0LmdldE93blByb3BlcnR5RGVzY3JpcHRvcihvYmplY3QsIHN5bSkuZW51bWVyYWJsZTtcbiAgICB9KTtcbiAgICBrZXlzLnB1c2guYXBwbHkoa2V5cywgc3ltYm9scyk7XG4gIH1cblxuICByZXR1cm4ga2V5cztcbn1cblxuZnVuY3Rpb24gX29iamVjdFNwcmVhZDIodGFyZ2V0KSB7XG4gIGZvciAodmFyIGkgPSAxOyBpIDwgYXJndW1lbnRzLmxlbmd0aDsgaSsrKSB7XG4gICAgdmFyIHNvdXJjZSA9IGFyZ3VtZW50c1tpXSAhPSBudWxsID8gYXJndW1lbnRzW2ldIDoge307XG5cbiAgICBpZiAoaSAlIDIpIHtcbiAgICAgIG93bktleXMoT2JqZWN0KHNvdXJjZSksIHRydWUpLmZvckVhY2goZnVuY3Rpb24gKGtleSkge1xuICAgICAgICBfZGVmaW5lUHJvcGVydHkodGFyZ2V0LCBrZXksIHNvdXJjZVtrZXldKTtcbiAgICAgIH0pO1xuICAgIH0gZWxzZSBpZiAoT2JqZWN0LmdldE93blByb3BlcnR5RGVzY3JpcHRvcnMpIHtcbiAgICAgIE9iamVjdC5kZWZpbmVQcm9wZXJ0aWVzKHRhcmdldCwgT2JqZWN0LmdldE93blByb3BlcnR5RGVzY3JpcHRvcnMoc291cmNlKSk7XG4gICAgfSBlbHNlIHtcbiAgICAgIG93bktleXMoT2JqZWN0KHNvdXJjZSkpLmZvckVhY2goZnVuY3Rpb24gKGtleSkge1xuICAgICAgICBPYmplY3QuZGVmaW5lUHJvcGVydHkodGFyZ2V0LCBrZXksIE9iamVjdC5nZXRPd25Qcm9wZXJ0eURlc2NyaXB0b3Ioc291cmNlLCBrZXkpKTtcbiAgICAgIH0pO1xuICAgIH1cbiAgfVxuXG4gIHJldHVybiB0YXJnZXQ7XG59XG5cbmZ1bmN0aW9uIGNvbXBvc2UoKSB7XG4gIGZvciAodmFyIF9sZW4gPSBhcmd1bWVudHMubGVuZ3RoLCBmbnMgPSBuZXcgQXJyYXkoX2xlbiksIF9rZXkgPSAwOyBfa2V5IDwgX2xlbjsgX2tleSsrKSB7XG4gICAgZm5zW19rZXldID0gYXJndW1lbnRzW19rZXldO1xuICB9XG5cbiAgcmV0dXJuIGZ1bmN0aW9uICh4KSB7XG4gICAgcmV0dXJuIGZucy5yZWR1Y2VSaWdodChmdW5jdGlvbiAoeSwgZikge1xuICAgICAgcmV0dXJuIGYoeSk7XG4gICAgfSwgeCk7XG4gIH07XG59XG5cbmZ1bmN0aW9uIGN1cnJ5KGZuKSB7XG4gIHJldHVybiBmdW5jdGlvbiBjdXJyaWVkKCkge1xuICAgIHZhciBfdGhpcyA9IHRoaXM7XG5cbiAgICBmb3IgKHZhciBfbGVuMiA9IGFyZ3VtZW50cy5sZW5ndGgsIGFyZ3MgPSBuZXcgQXJyYXkoX2xlbjIpLCBfa2V5MiA9IDA7IF9rZXkyIDwgX2xlbjI7IF9rZXkyKyspIHtcbiAgICAgIGFyZ3NbX2tleTJdID0gYXJndW1lbnRzW19rZXkyXTtcbiAgICB9XG5cbiAgICByZXR1cm4gYXJncy5sZW5ndGggPj0gZm4ubGVuZ3RoID8gZm4uYXBwbHkodGhpcywgYXJncykgOiBmdW5jdGlvbiAoKSB7XG4gICAgICBmb3IgKHZhciBfbGVuMyA9IGFyZ3VtZW50cy5sZW5ndGgsIG5leHRBcmdzID0gbmV3IEFycmF5KF9sZW4zKSwgX2tleTMgPSAwOyBfa2V5MyA8IF9sZW4zOyBfa2V5MysrKSB7XG4gICAgICAgIG5leHRBcmdzW19rZXkzXSA9IGFyZ3VtZW50c1tfa2V5M107XG4gICAgICB9XG5cbiAgICAgIHJldHVybiBjdXJyaWVkLmFwcGx5KF90aGlzLCBbXS5jb25jYXQoYXJncywgbmV4dEFyZ3MpKTtcbiAgICB9O1xuICB9O1xufVxuXG5mdW5jdGlvbiBpc09iamVjdCh2YWx1ZSkge1xuICByZXR1cm4ge30udG9TdHJpbmcuY2FsbCh2YWx1ZSkuaW5jbHVkZXMoJ09iamVjdCcpO1xufVxuXG5mdW5jdGlvbiBpc0VtcHR5KG9iaikge1xuICByZXR1cm4gIU9iamVjdC5rZXlzKG9iaikubGVuZ3RoO1xufVxuXG5mdW5jdGlvbiBpc0Z1bmN0aW9uKHZhbHVlKSB7XG4gIHJldHVybiB0eXBlb2YgdmFsdWUgPT09ICdmdW5jdGlvbic7XG59XG5cbmZ1bmN0aW9uIGhhc093blByb3BlcnR5KG9iamVjdCwgcHJvcGVydHkpIHtcbiAgcmV0dXJuIE9iamVjdC5wcm90b3R5cGUuaGFzT3duUHJvcGVydHkuY2FsbChvYmplY3QsIHByb3BlcnR5KTtcbn1cblxuZnVuY3Rpb24gdmFsaWRhdGVDaGFuZ2VzKGluaXRpYWwsIGNoYW5nZXMpIHtcbiAgaWYgKCFpc09iamVjdChjaGFuZ2VzKSkgZXJyb3JIYW5kbGVyKCdjaGFuZ2VUeXBlJyk7XG4gIGlmIChPYmplY3Qua2V5cyhjaGFuZ2VzKS5zb21lKGZ1bmN0aW9uIChmaWVsZCkge1xuICAgIHJldHVybiAhaGFzT3duUHJvcGVydHkoaW5pdGlhbCwgZmllbGQpO1xuICB9KSkgZXJyb3JIYW5kbGVyKCdjaGFuZ2VGaWVsZCcpO1xuICByZXR1cm4gY2hhbmdlcztcbn1cblxuZnVuY3Rpb24gdmFsaWRhdGVTZWxlY3RvcihzZWxlY3Rvcikge1xuICBpZiAoIWlzRnVuY3Rpb24oc2VsZWN0b3IpKSBlcnJvckhhbmRsZXIoJ3NlbGVjdG9yVHlwZScpO1xufVxuXG5mdW5jdGlvbiB2YWxpZGF0ZUhhbmRsZXIoaGFuZGxlcikge1xuICBpZiAoIShpc0Z1bmN0aW9uKGhhbmRsZXIpIHx8IGlzT2JqZWN0KGhhbmRsZXIpKSkgZXJyb3JIYW5kbGVyKCdoYW5kbGVyVHlwZScpO1xuICBpZiAoaXNPYmplY3QoaGFuZGxlcikgJiYgT2JqZWN0LnZhbHVlcyhoYW5kbGVyKS5zb21lKGZ1bmN0aW9uIChfaGFuZGxlcikge1xuICAgIHJldHVybiAhaXNGdW5jdGlvbihfaGFuZGxlcik7XG4gIH0pKSBlcnJvckhhbmRsZXIoJ2hhbmRsZXJzVHlwZScpO1xufVxuXG5mdW5jdGlvbiB2YWxpZGF0ZUluaXRpYWwoaW5pdGlhbCkge1xuICBpZiAoIWluaXRpYWwpIGVycm9ySGFuZGxlcignaW5pdGlhbElzUmVxdWlyZWQnKTtcbiAgaWYgKCFpc09iamVjdChpbml0aWFsKSkgZXJyb3JIYW5kbGVyKCdpbml0aWFsVHlwZScpO1xuICBpZiAoaXNFbXB0eShpbml0aWFsKSkgZXJyb3JIYW5kbGVyKCdpbml0aWFsQ29udGVudCcpO1xufVxuXG5mdW5jdGlvbiB0aHJvd0Vycm9yKGVycm9yTWVzc2FnZXMsIHR5cGUpIHtcbiAgdGhyb3cgbmV3IEVycm9yKGVycm9yTWVzc2FnZXNbdHlwZV0gfHwgZXJyb3JNZXNzYWdlc1tcImRlZmF1bHRcIl0pO1xufVxuXG52YXIgZXJyb3JNZXNzYWdlcyA9IHtcbiAgaW5pdGlhbElzUmVxdWlyZWQ6ICdpbml0aWFsIHN0YXRlIGlzIHJlcXVpcmVkJyxcbiAgaW5pdGlhbFR5cGU6ICdpbml0aWFsIHN0YXRlIHNob3VsZCBiZSBhbiBvYmplY3QnLFxuICBpbml0aWFsQ29udGVudDogJ2luaXRpYWwgc3RhdGUgc2hvdWxkblxcJ3QgYmUgYW4gZW1wdHkgb2JqZWN0JyxcbiAgaGFuZGxlclR5cGU6ICdoYW5kbGVyIHNob3VsZCBiZSBhbiBvYmplY3Qgb3IgYSBmdW5jdGlvbicsXG4gIGhhbmRsZXJzVHlwZTogJ2FsbCBoYW5kbGVycyBzaG91bGQgYmUgYSBmdW5jdGlvbnMnLFxuICBzZWxlY3RvclR5cGU6ICdzZWxlY3RvciBzaG91bGQgYmUgYSBmdW5jdGlvbicsXG4gIGNoYW5nZVR5cGU6ICdwcm92aWRlZCB2YWx1ZSBvZiBjaGFuZ2VzIHNob3VsZCBiZSBhbiBvYmplY3QnLFxuICBjaGFuZ2VGaWVsZDogJ2l0IHNlYW1zIHlvdSB3YW50IHRvIGNoYW5nZSBhIGZpZWxkIGluIHRoZSBzdGF0ZSB3aGljaCBpcyBub3Qgc3BlY2lmaWVkIGluIHRoZSBcImluaXRpYWxcIiBzdGF0ZScsXG4gIFwiZGVmYXVsdFwiOiAnYW4gdW5rbm93biBlcnJvciBhY2N1cmVkIGluIGBzdGF0ZS1sb2NhbGAgcGFja2FnZSdcbn07XG52YXIgZXJyb3JIYW5kbGVyID0gY3VycnkodGhyb3dFcnJvcikoZXJyb3JNZXNzYWdlcyk7XG52YXIgdmFsaWRhdG9ycyA9IHtcbiAgY2hhbmdlczogdmFsaWRhdGVDaGFuZ2VzLFxuICBzZWxlY3RvcjogdmFsaWRhdGVTZWxlY3RvcixcbiAgaGFuZGxlcjogdmFsaWRhdGVIYW5kbGVyLFxuICBpbml0aWFsOiB2YWxpZGF0ZUluaXRpYWxcbn07XG5cbmZ1bmN0aW9uIGNyZWF0ZShpbml0aWFsKSB7XG4gIHZhciBoYW5kbGVyID0gYXJndW1lbnRzLmxlbmd0aCA+IDEgJiYgYXJndW1lbnRzWzFdICE9PSB1bmRlZmluZWQgPyBhcmd1bWVudHNbMV0gOiB7fTtcbiAgdmFsaWRhdG9ycy5pbml0aWFsKGluaXRpYWwpO1xuICB2YWxpZGF0b3JzLmhhbmRsZXIoaGFuZGxlcik7XG4gIHZhciBzdGF0ZSA9IHtcbiAgICBjdXJyZW50OiBpbml0aWFsXG4gIH07XG4gIHZhciBkaWRVcGRhdGUgPSBjdXJyeShkaWRTdGF0ZVVwZGF0ZSkoc3RhdGUsIGhhbmRsZXIpO1xuICB2YXIgdXBkYXRlID0gY3VycnkodXBkYXRlU3RhdGUpKHN0YXRlKTtcbiAgdmFyIHZhbGlkYXRlID0gY3VycnkodmFsaWRhdG9ycy5jaGFuZ2VzKShpbml0aWFsKTtcbiAgdmFyIGdldENoYW5nZXMgPSBjdXJyeShleHRyYWN0Q2hhbmdlcykoc3RhdGUpO1xuXG4gIGZ1bmN0aW9uIGdldFN0YXRlKCkge1xuICAgIHZhciBzZWxlY3RvciA9IGFyZ3VtZW50cy5sZW5ndGggPiAwICYmIGFyZ3VtZW50c1swXSAhPT0gdW5kZWZpbmVkID8gYXJndW1lbnRzWzBdIDogZnVuY3Rpb24gKHN0YXRlKSB7XG4gICAgICByZXR1cm4gc3RhdGU7XG4gICAgfTtcbiAgICB2YWxpZGF0b3JzLnNlbGVjdG9yKHNlbGVjdG9yKTtcbiAgICByZXR1cm4gc2VsZWN0b3Ioc3RhdGUuY3VycmVudCk7XG4gIH1cblxuICBmdW5jdGlvbiBzZXRTdGF0ZShjYXVzZWRDaGFuZ2VzKSB7XG4gICAgY29tcG9zZShkaWRVcGRhdGUsIHVwZGF0ZSwgdmFsaWRhdGUsIGdldENoYW5nZXMpKGNhdXNlZENoYW5nZXMpO1xuICB9XG5cbiAgcmV0dXJuIFtnZXRTdGF0ZSwgc2V0U3RhdGVdO1xufVxuXG5mdW5jdGlvbiBleHRyYWN0Q2hhbmdlcyhzdGF0ZSwgY2F1c2VkQ2hhbmdlcykge1xuICByZXR1cm4gaXNGdW5jdGlvbihjYXVzZWRDaGFuZ2VzKSA/IGNhdXNlZENoYW5nZXMoc3RhdGUuY3VycmVudCkgOiBjYXVzZWRDaGFuZ2VzO1xufVxuXG5mdW5jdGlvbiB1cGRhdGVTdGF0ZShzdGF0ZSwgY2hhbmdlcykge1xuICBzdGF0ZS5jdXJyZW50ID0gX29iamVjdFNwcmVhZDIoX29iamVjdFNwcmVhZDIoe30sIHN0YXRlLmN1cnJlbnQpLCBjaGFuZ2VzKTtcbiAgcmV0dXJuIGNoYW5nZXM7XG59XG5cbmZ1bmN0aW9uIGRpZFN0YXRlVXBkYXRlKHN0YXRlLCBoYW5kbGVyLCBjaGFuZ2VzKSB7XG4gIGlzRnVuY3Rpb24oaGFuZGxlcikgPyBoYW5kbGVyKHN0YXRlLmN1cnJlbnQpIDogT2JqZWN0LmtleXMoY2hhbmdlcykuZm9yRWFjaChmdW5jdGlvbiAoZmllbGQpIHtcbiAgICB2YXIgX2hhbmRsZXIkZmllbGQ7XG5cbiAgICByZXR1cm4gKF9oYW5kbGVyJGZpZWxkID0gaGFuZGxlcltmaWVsZF0pID09PSBudWxsIHx8IF9oYW5kbGVyJGZpZWxkID09PSB2b2lkIDAgPyB2b2lkIDAgOiBfaGFuZGxlciRmaWVsZC5jYWxsKGhhbmRsZXIsIHN0YXRlLmN1cnJlbnRbZmllbGRdKTtcbiAgfSk7XG4gIHJldHVybiBjaGFuZ2VzO1xufVxuXG52YXIgaW5kZXggPSB7XG4gIGNyZWF0ZTogY3JlYXRlXG59O1xuXG5leHBvcnQgZGVmYXVsdCBpbmRleDtcbiIsICJ2YXIgY29uZmlnID0ge1xuICBwYXRoczoge1xuICAgIHZzOiAnaHR0cHM6Ly9jZG4uanNkZWxpdnIubmV0L25wbS9tb25hY28tZWRpdG9yQDAuMzYuMS9taW4vdnMnXG4gIH1cbn07XG5cbmV4cG9ydCBkZWZhdWx0IGNvbmZpZztcbiIsICJmdW5jdGlvbiBjdXJyeShmbikge1xuICByZXR1cm4gZnVuY3Rpb24gY3VycmllZCgpIHtcbiAgICB2YXIgX3RoaXMgPSB0aGlzO1xuXG4gICAgZm9yICh2YXIgX2xlbiA9IGFyZ3VtZW50cy5sZW5ndGgsIGFyZ3MgPSBuZXcgQXJyYXkoX2xlbiksIF9rZXkgPSAwOyBfa2V5IDwgX2xlbjsgX2tleSsrKSB7XG4gICAgICBhcmdzW19rZXldID0gYXJndW1lbnRzW19rZXldO1xuICAgIH1cblxuICAgIHJldHVybiBhcmdzLmxlbmd0aCA+PSBmbi5sZW5ndGggPyBmbi5hcHBseSh0aGlzLCBhcmdzKSA6IGZ1bmN0aW9uICgpIHtcbiAgICAgIGZvciAodmFyIF9sZW4yID0gYXJndW1lbnRzLmxlbmd0aCwgbmV4dEFyZ3MgPSBuZXcgQXJyYXkoX2xlbjIpLCBfa2V5MiA9IDA7IF9rZXkyIDwgX2xlbjI7IF9rZXkyKyspIHtcbiAgICAgICAgbmV4dEFyZ3NbX2tleTJdID0gYXJndW1lbnRzW19rZXkyXTtcbiAgICAgIH1cblxuICAgICAgcmV0dXJuIGN1cnJpZWQuYXBwbHkoX3RoaXMsIFtdLmNvbmNhdChhcmdzLCBuZXh0QXJncykpO1xuICAgIH07XG4gIH07XG59XG5cbmV4cG9ydCBkZWZhdWx0IGN1cnJ5O1xuIiwgImZ1bmN0aW9uIGlzT2JqZWN0KHZhbHVlKSB7XG4gIHJldHVybiB7fS50b1N0cmluZy5jYWxsKHZhbHVlKS5pbmNsdWRlcygnT2JqZWN0Jyk7XG59XG5cbmV4cG9ydCBkZWZhdWx0IGlzT2JqZWN0O1xuIiwgImltcG9ydCBjdXJyeSBmcm9tICcuLi91dGlscy9jdXJyeS5qcyc7XG5pbXBvcnQgaXNPYmplY3QgZnJvbSAnLi4vdXRpbHMvaXNPYmplY3QuanMnO1xuXG4vKipcbiAqIHZhbGlkYXRlcyB0aGUgY29uZmlndXJhdGlvbiBvYmplY3QgYW5kIGluZm9ybXMgYWJvdXQgZGVwcmVjYXRpb25cbiAqIEBwYXJhbSB7T2JqZWN0fSBjb25maWcgLSB0aGUgY29uZmlndXJhdGlvbiBvYmplY3QgXG4gKiBAcmV0dXJuIHtPYmplY3R9IGNvbmZpZyAtIHRoZSB2YWxpZGF0ZWQgY29uZmlndXJhdGlvbiBvYmplY3RcbiAqL1xuXG5mdW5jdGlvbiB2YWxpZGF0ZUNvbmZpZyhjb25maWcpIHtcbiAgaWYgKCFjb25maWcpIGVycm9ySGFuZGxlcignY29uZmlnSXNSZXF1aXJlZCcpO1xuICBpZiAoIWlzT2JqZWN0KGNvbmZpZykpIGVycm9ySGFuZGxlcignY29uZmlnVHlwZScpO1xuXG4gIGlmIChjb25maWcudXJscykge1xuICAgIGluZm9ybUFib3V0RGVwcmVjYXRpb24oKTtcbiAgICByZXR1cm4ge1xuICAgICAgcGF0aHM6IHtcbiAgICAgICAgdnM6IGNvbmZpZy51cmxzLm1vbmFjb0Jhc2VcbiAgICAgIH1cbiAgICB9O1xuICB9XG5cbiAgcmV0dXJuIGNvbmZpZztcbn1cbi8qKlxuICogbG9ncyBkZXByZWNhdGlvbiBtZXNzYWdlXG4gKi9cblxuXG5mdW5jdGlvbiBpbmZvcm1BYm91dERlcHJlY2F0aW9uKCkge1xuICBjb25zb2xlLndhcm4oZXJyb3JNZXNzYWdlcy5kZXByZWNhdGlvbik7XG59XG5cbmZ1bmN0aW9uIHRocm93RXJyb3IoZXJyb3JNZXNzYWdlcywgdHlwZSkge1xuICB0aHJvdyBuZXcgRXJyb3IoZXJyb3JNZXNzYWdlc1t0eXBlXSB8fCBlcnJvck1lc3NhZ2VzW1wiZGVmYXVsdFwiXSk7XG59XG5cbnZhciBlcnJvck1lc3NhZ2VzID0ge1xuICBjb25maWdJc1JlcXVpcmVkOiAndGhlIGNvbmZpZ3VyYXRpb24gb2JqZWN0IGlzIHJlcXVpcmVkJyxcbiAgY29uZmlnVHlwZTogJ3RoZSBjb25maWd1cmF0aW9uIG9iamVjdCBzaG91bGQgYmUgYW4gb2JqZWN0JyxcbiAgXCJkZWZhdWx0XCI6ICdhbiB1bmtub3duIGVycm9yIGFjY3VyZWQgaW4gYEBtb25hY28tZWRpdG9yL2xvYWRlcmAgcGFja2FnZScsXG4gIGRlcHJlY2F0aW9uOiBcIkRlcHJlY2F0aW9uIHdhcm5pbmchXFxuICAgIFlvdSBhcmUgdXNpbmcgZGVwcmVjYXRlZCB3YXkgb2YgY29uZmlndXJhdGlvbi5cXG5cXG4gICAgSW5zdGVhZCBvZiB1c2luZ1xcbiAgICAgIG1vbmFjby5jb25maWcoeyB1cmxzOiB7IG1vbmFjb0Jhc2U6ICcuLi4nIH0gfSlcXG4gICAgdXNlXFxuICAgICAgbW9uYWNvLmNvbmZpZyh7IHBhdGhzOiB7IHZzOiAnLi4uJyB9IH0pXFxuXFxuICAgIEZvciBtb3JlIHBsZWFzZSBjaGVjayB0aGUgbGluayBodHRwczovL2dpdGh1Yi5jb20vc3VyZW4tYXRveWFuL21vbmFjby1sb2FkZXIjY29uZmlnXFxuICBcIlxufTtcbnZhciBlcnJvckhhbmRsZXIgPSBjdXJyeSh0aHJvd0Vycm9yKShlcnJvck1lc3NhZ2VzKTtcbnZhciB2YWxpZGF0b3JzID0ge1xuICBjb25maWc6IHZhbGlkYXRlQ29uZmlnXG59O1xuXG5leHBvcnQgZGVmYXVsdCB2YWxpZGF0b3JzO1xuZXhwb3J0IHsgZXJyb3JIYW5kbGVyLCBlcnJvck1lc3NhZ2VzIH07XG4iLCAidmFyIGNvbXBvc2UgPSBmdW5jdGlvbiBjb21wb3NlKCkge1xuICBmb3IgKHZhciBfbGVuID0gYXJndW1lbnRzLmxlbmd0aCwgZm5zID0gbmV3IEFycmF5KF9sZW4pLCBfa2V5ID0gMDsgX2tleSA8IF9sZW47IF9rZXkrKykge1xuICAgIGZuc1tfa2V5XSA9IGFyZ3VtZW50c1tfa2V5XTtcbiAgfVxuXG4gIHJldHVybiBmdW5jdGlvbiAoeCkge1xuICAgIHJldHVybiBmbnMucmVkdWNlUmlnaHQoZnVuY3Rpb24gKHksIGYpIHtcbiAgICAgIHJldHVybiBmKHkpO1xuICAgIH0sIHgpO1xuICB9O1xufTtcblxuZXhwb3J0IGRlZmF1bHQgY29tcG9zZTtcbiIsICJpbXBvcnQgeyBvYmplY3RTcHJlYWQyIGFzIF9vYmplY3RTcHJlYWQyIH0gZnJvbSAnLi4vX3ZpcnR1YWwvX3JvbGx1cFBsdWdpbkJhYmVsSGVscGVycy5qcyc7XG5cbmZ1bmN0aW9uIG1lcmdlKHRhcmdldCwgc291cmNlKSB7XG4gIE9iamVjdC5rZXlzKHNvdXJjZSkuZm9yRWFjaChmdW5jdGlvbiAoa2V5KSB7XG4gICAgaWYgKHNvdXJjZVtrZXldIGluc3RhbmNlb2YgT2JqZWN0KSB7XG4gICAgICBpZiAodGFyZ2V0W2tleV0pIHtcbiAgICAgICAgT2JqZWN0LmFzc2lnbihzb3VyY2Vba2V5XSwgbWVyZ2UodGFyZ2V0W2tleV0sIHNvdXJjZVtrZXldKSk7XG4gICAgICB9XG4gICAgfVxuICB9KTtcbiAgcmV0dXJuIF9vYmplY3RTcHJlYWQyKF9vYmplY3RTcHJlYWQyKHt9LCB0YXJnZXQpLCBzb3VyY2UpO1xufVxuXG5leHBvcnQgZGVmYXVsdCBtZXJnZTtcbiIsICIvLyBUaGUgc291cmNlIChoYXMgYmVlbiBjaGFuZ2VkKSBpcyBodHRwczovL2dpdGh1Yi5jb20vZmFjZWJvb2svcmVhY3QvaXNzdWVzLzU0NjUjaXNzdWVjb21tZW50LTE1Nzg4ODMyNVxudmFyIENBTkNFTEFUSU9OX01FU1NBR0UgPSB7XG4gIHR5cGU6ICdjYW5jZWxhdGlvbicsXG4gIG1zZzogJ29wZXJhdGlvbiBpcyBtYW51YWxseSBjYW5jZWxlZCdcbn07XG5cbmZ1bmN0aW9uIG1ha2VDYW5jZWxhYmxlKHByb21pc2UpIHtcbiAgdmFyIGhhc0NhbmNlbGVkXyA9IGZhbHNlO1xuICB2YXIgd3JhcHBlZFByb21pc2UgPSBuZXcgUHJvbWlzZShmdW5jdGlvbiAocmVzb2x2ZSwgcmVqZWN0KSB7XG4gICAgcHJvbWlzZS50aGVuKGZ1bmN0aW9uICh2YWwpIHtcbiAgICAgIHJldHVybiBoYXNDYW5jZWxlZF8gPyByZWplY3QoQ0FOQ0VMQVRJT05fTUVTU0FHRSkgOiByZXNvbHZlKHZhbCk7XG4gICAgfSk7XG4gICAgcHJvbWlzZVtcImNhdGNoXCJdKHJlamVjdCk7XG4gIH0pO1xuICByZXR1cm4gd3JhcHBlZFByb21pc2UuY2FuY2VsID0gZnVuY3Rpb24gKCkge1xuICAgIHJldHVybiBoYXNDYW5jZWxlZF8gPSB0cnVlO1xuICB9LCB3cmFwcGVkUHJvbWlzZTtcbn1cblxuZXhwb3J0IGRlZmF1bHQgbWFrZUNhbmNlbGFibGU7XG5leHBvcnQgeyBDQU5DRUxBVElPTl9NRVNTQUdFIH07XG4iLCAiaW1wb3J0IHsgc2xpY2VkVG9BcnJheSBhcyBfc2xpY2VkVG9BcnJheSwgb2JqZWN0V2l0aG91dFByb3BlcnRpZXMgYXMgX29iamVjdFdpdGhvdXRQcm9wZXJ0aWVzIH0gZnJvbSAnLi4vX3ZpcnR1YWwvX3JvbGx1cFBsdWdpbkJhYmVsSGVscGVycy5qcyc7XG5pbXBvcnQgc3RhdGUgZnJvbSAnc3RhdGUtbG9jYWwnO1xuaW1wb3J0IGNvbmZpZyQxIGZyb20gJy4uL2NvbmZpZy9pbmRleC5qcyc7XG5pbXBvcnQgdmFsaWRhdG9ycyBmcm9tICcuLi92YWxpZGF0b3JzL2luZGV4LmpzJztcbmltcG9ydCBjb21wb3NlIGZyb20gJy4uL3V0aWxzL2NvbXBvc2UuanMnO1xuaW1wb3J0IG1lcmdlIGZyb20gJy4uL3V0aWxzL2RlZXBNZXJnZS5qcyc7XG5pbXBvcnQgbWFrZUNhbmNlbGFibGUgZnJvbSAnLi4vdXRpbHMvbWFrZUNhbmNlbGFibGUuanMnO1xuXG4vKiogdGhlIGxvY2FsIHN0YXRlIG9mIHRoZSBtb2R1bGUgKi9cblxudmFyIF9zdGF0ZSRjcmVhdGUgPSBzdGF0ZS5jcmVhdGUoe1xuICBjb25maWc6IGNvbmZpZyQxLFxuICBpc0luaXRpYWxpemVkOiBmYWxzZSxcbiAgcmVzb2x2ZTogbnVsbCxcbiAgcmVqZWN0OiBudWxsLFxuICBtb25hY286IG51bGxcbn0pLFxuICAgIF9zdGF0ZSRjcmVhdGUyID0gX3NsaWNlZFRvQXJyYXkoX3N0YXRlJGNyZWF0ZSwgMiksXG4gICAgZ2V0U3RhdGUgPSBfc3RhdGUkY3JlYXRlMlswXSxcbiAgICBzZXRTdGF0ZSA9IF9zdGF0ZSRjcmVhdGUyWzFdO1xuLyoqXG4gKiBzZXQgdGhlIGxvYWRlciBjb25maWd1cmF0aW9uXG4gKiBAcGFyYW0ge09iamVjdH0gY29uZmlnIC0gdGhlIGNvbmZpZ3VyYXRpb24gb2JqZWN0XG4gKi9cblxuXG5mdW5jdGlvbiBjb25maWcoZ2xvYmFsQ29uZmlnKSB7XG4gIHZhciBfdmFsaWRhdG9ycyRjb25maWcgPSB2YWxpZGF0b3JzLmNvbmZpZyhnbG9iYWxDb25maWcpLFxuICAgICAgbW9uYWNvID0gX3ZhbGlkYXRvcnMkY29uZmlnLm1vbmFjbyxcbiAgICAgIGNvbmZpZyA9IF9vYmplY3RXaXRob3V0UHJvcGVydGllcyhfdmFsaWRhdG9ycyRjb25maWcsIFtcIm1vbmFjb1wiXSk7XG5cbiAgc2V0U3RhdGUoZnVuY3Rpb24gKHN0YXRlKSB7XG4gICAgcmV0dXJuIHtcbiAgICAgIGNvbmZpZzogbWVyZ2Uoc3RhdGUuY29uZmlnLCBjb25maWcpLFxuICAgICAgbW9uYWNvOiBtb25hY29cbiAgICB9O1xuICB9KTtcbn1cbi8qKlxuICogaGFuZGxlcyB0aGUgaW5pdGlhbGl6YXRpb24gb2YgdGhlIG1vbmFjby1lZGl0b3JcbiAqIEByZXR1cm4ge1Byb21pc2V9IC0gcmV0dXJucyBhbiBpbnN0YW5jZSBvZiBtb25hY28gKHdpdGggYSBjYW5jZWxhYmxlIHByb21pc2UpXG4gKi9cblxuXG5mdW5jdGlvbiBpbml0KCkge1xuICB2YXIgc3RhdGUgPSBnZXRTdGF0ZShmdW5jdGlvbiAoX3JlZikge1xuICAgIHZhciBtb25hY28gPSBfcmVmLm1vbmFjbyxcbiAgICAgICAgaXNJbml0aWFsaXplZCA9IF9yZWYuaXNJbml0aWFsaXplZCxcbiAgICAgICAgcmVzb2x2ZSA9IF9yZWYucmVzb2x2ZTtcbiAgICByZXR1cm4ge1xuICAgICAgbW9uYWNvOiBtb25hY28sXG4gICAgICBpc0luaXRpYWxpemVkOiBpc0luaXRpYWxpemVkLFxuICAgICAgcmVzb2x2ZTogcmVzb2x2ZVxuICAgIH07XG4gIH0pO1xuXG4gIGlmICghc3RhdGUuaXNJbml0aWFsaXplZCkge1xuICAgIHNldFN0YXRlKHtcbiAgICAgIGlzSW5pdGlhbGl6ZWQ6IHRydWVcbiAgICB9KTtcblxuICAgIGlmIChzdGF0ZS5tb25hY28pIHtcbiAgICAgIHN0YXRlLnJlc29sdmUoc3RhdGUubW9uYWNvKTtcbiAgICAgIHJldHVybiBtYWtlQ2FuY2VsYWJsZSh3cmFwcGVyUHJvbWlzZSk7XG4gICAgfVxuXG4gICAgaWYgKHdpbmRvdy5tb25hY28gJiYgd2luZG93Lm1vbmFjby5lZGl0b3IpIHtcbiAgICAgIHN0b3JlTW9uYWNvSW5zdGFuY2Uod2luZG93Lm1vbmFjbyk7XG4gICAgICBzdGF0ZS5yZXNvbHZlKHdpbmRvdy5tb25hY28pO1xuICAgICAgcmV0dXJuIG1ha2VDYW5jZWxhYmxlKHdyYXBwZXJQcm9taXNlKTtcbiAgICB9XG5cbiAgICBjb21wb3NlKGluamVjdFNjcmlwdHMsIGdldE1vbmFjb0xvYWRlclNjcmlwdCkoY29uZmlndXJlTG9hZGVyKTtcbiAgfVxuXG4gIHJldHVybiBtYWtlQ2FuY2VsYWJsZSh3cmFwcGVyUHJvbWlzZSk7XG59XG4vKipcbiAqIGluamVjdHMgcHJvdmlkZWQgc2NyaXB0cyBpbnRvIHRoZSBkb2N1bWVudC5ib2R5XG4gKiBAcGFyYW0ge09iamVjdH0gc2NyaXB0IC0gYW4gSFRNTCBzY3JpcHQgZWxlbWVudFxuICogQHJldHVybiB7T2JqZWN0fSAtIHRoZSBpbmplY3RlZCBIVE1MIHNjcmlwdCBlbGVtZW50XG4gKi9cblxuXG5mdW5jdGlvbiBpbmplY3RTY3JpcHRzKHNjcmlwdCkge1xuICByZXR1cm4gZG9jdW1lbnQuYm9keS5hcHBlbmRDaGlsZChzY3JpcHQpO1xufVxuLyoqXG4gKiBjcmVhdGVzIGFuIEhUTUwgc2NyaXB0IGVsZW1lbnQgd2l0aC93aXRob3V0IHByb3ZpZGVkIHNyY1xuICogQHBhcmFtIHtzdHJpbmd9IFtzcmNdIC0gdGhlIHNvdXJjZSBwYXRoIG9mIHRoZSBzY3JpcHRcbiAqIEByZXR1cm4ge09iamVjdH0gLSB0aGUgY3JlYXRlZCBIVE1MIHNjcmlwdCBlbGVtZW50XG4gKi9cblxuXG5mdW5jdGlvbiBjcmVhdGVTY3JpcHQoc3JjKSB7XG4gIHZhciBzY3JpcHQgPSBkb2N1bWVudC5jcmVhdGVFbGVtZW50KCdzY3JpcHQnKTtcbiAgcmV0dXJuIHNyYyAmJiAoc2NyaXB0LnNyYyA9IHNyYyksIHNjcmlwdDtcbn1cbi8qKlxuICogY3JlYXRlcyBhbiBIVE1MIHNjcmlwdCBlbGVtZW50IHdpdGggdGhlIG1vbmFjbyBsb2FkZXIgc3JjXG4gKiBAcmV0dXJuIHtPYmplY3R9IC0gdGhlIGNyZWF0ZWQgSFRNTCBzY3JpcHQgZWxlbWVudFxuICovXG5cblxuZnVuY3Rpb24gZ2V0TW9uYWNvTG9hZGVyU2NyaXB0KGNvbmZpZ3VyZUxvYWRlcikge1xuICB2YXIgc3RhdGUgPSBnZXRTdGF0ZShmdW5jdGlvbiAoX3JlZjIpIHtcbiAgICB2YXIgY29uZmlnID0gX3JlZjIuY29uZmlnLFxuICAgICAgICByZWplY3QgPSBfcmVmMi5yZWplY3Q7XG4gICAgcmV0dXJuIHtcbiAgICAgIGNvbmZpZzogY29uZmlnLFxuICAgICAgcmVqZWN0OiByZWplY3RcbiAgICB9O1xuICB9KTtcbiAgdmFyIGxvYWRlclNjcmlwdCA9IGNyZWF0ZVNjcmlwdChcIlwiLmNvbmNhdChzdGF0ZS5jb25maWcucGF0aHMudnMsIFwiL2xvYWRlci5qc1wiKSk7XG5cbiAgbG9hZGVyU2NyaXB0Lm9ubG9hZCA9IGZ1bmN0aW9uICgpIHtcbiAgICByZXR1cm4gY29uZmlndXJlTG9hZGVyKCk7XG4gIH07XG5cbiAgbG9hZGVyU2NyaXB0Lm9uZXJyb3IgPSBzdGF0ZS5yZWplY3Q7XG4gIHJldHVybiBsb2FkZXJTY3JpcHQ7XG59XG4vKipcbiAqIGNvbmZpZ3VyZXMgdGhlIG1vbmFjbyBsb2FkZXJcbiAqL1xuXG5cbmZ1bmN0aW9uIGNvbmZpZ3VyZUxvYWRlcigpIHtcbiAgdmFyIHN0YXRlID0gZ2V0U3RhdGUoZnVuY3Rpb24gKF9yZWYzKSB7XG4gICAgdmFyIGNvbmZpZyA9IF9yZWYzLmNvbmZpZyxcbiAgICAgICAgcmVzb2x2ZSA9IF9yZWYzLnJlc29sdmUsXG4gICAgICAgIHJlamVjdCA9IF9yZWYzLnJlamVjdDtcbiAgICByZXR1cm4ge1xuICAgICAgY29uZmlnOiBjb25maWcsXG4gICAgICByZXNvbHZlOiByZXNvbHZlLFxuICAgICAgcmVqZWN0OiByZWplY3RcbiAgICB9O1xuICB9KTtcbiAgdmFyIHJlcXVpcmUgPSB3aW5kb3cucmVxdWlyZTtcblxuICByZXF1aXJlLmNvbmZpZyhzdGF0ZS5jb25maWcpO1xuXG4gIHJlcXVpcmUoWyd2cy9lZGl0b3IvZWRpdG9yLm1haW4nXSwgZnVuY3Rpb24gKG1vbmFjbykge1xuICAgIHN0b3JlTW9uYWNvSW5zdGFuY2UobW9uYWNvKTtcbiAgICBzdGF0ZS5yZXNvbHZlKG1vbmFjbyk7XG4gIH0sIGZ1bmN0aW9uIChlcnJvcikge1xuICAgIHN0YXRlLnJlamVjdChlcnJvcik7XG4gIH0pO1xufVxuLyoqXG4gKiBzdG9yZSBtb25hY28gaW5zdGFuY2UgaW4gbG9jYWwgc3RhdGVcbiAqL1xuXG5cbmZ1bmN0aW9uIHN0b3JlTW9uYWNvSW5zdGFuY2UobW9uYWNvKSB7XG4gIGlmICghZ2V0U3RhdGUoKS5tb25hY28pIHtcbiAgICBzZXRTdGF0ZSh7XG4gICAgICBtb25hY286IG1vbmFjb1xuICAgIH0pO1xuICB9XG59XG4vKipcbiAqIGludGVybmFsIGhlbHBlciBmdW5jdGlvblxuICogZXh0cmFjdHMgc3RvcmVkIG1vbmFjbyBpbnN0YW5jZVxuICogQHJldHVybiB7T2JqZWN0fG51bGx9IC0gdGhlIG1vbmFjbyBpbnN0YW5jZVxuICovXG5cblxuZnVuY3Rpb24gX19nZXRNb25hY29JbnN0YW5jZSgpIHtcbiAgcmV0dXJuIGdldFN0YXRlKGZ1bmN0aW9uIChfcmVmNCkge1xuICAgIHZhciBtb25hY28gPSBfcmVmNC5tb25hY287XG4gICAgcmV0dXJuIG1vbmFjbztcbiAgfSk7XG59XG5cbnZhciB3cmFwcGVyUHJvbWlzZSA9IG5ldyBQcm9taXNlKGZ1bmN0aW9uIChyZXNvbHZlLCByZWplY3QpIHtcbiAgcmV0dXJuIHNldFN0YXRlKHtcbiAgICByZXNvbHZlOiByZXNvbHZlLFxuICAgIHJlamVjdDogcmVqZWN0XG4gIH0pO1xufSk7XG52YXIgbG9hZGVyID0ge1xuICBjb25maWc6IGNvbmZpZyxcbiAgaW5pdDogaW5pdCxcbiAgX19nZXRNb25hY29JbnN0YW5jZTogX19nZXRNb25hY29JbnN0YW5jZVxufTtcblxuZXhwb3J0IGRlZmF1bHQgbG9hZGVyO1xuIiwgIi8vIGh0dHBzOi8vZ2l0aHViLmNvbS9saXZlYm9vay1kZXYvbGl2ZWJvb2svYmxvYi8yM2U1OGFjNjA0ZGU5MmNlNTQ0NzJmMzZmZTNlMjhkYzI3NTc2ZDZjL2Fzc2V0cy9qcy9ob29rcy9jZWxsX2VkaXRvci9saXZlX2VkaXRvci90aGVtZS5qc1xuXG4vLyBUaGlzIGlzIGEgcG9ydCBvZiB0aGUgT25lIERhcmsgdGhlbWUgdG8gdGhlIE1vbmFjbyBlZGl0b3IuXG4vLyBXZSBjb2xvciBncmFkZWQgdGhlIGNvbW1lbnQgc28gaXQgaGFzIEFBIGFjY2Vzc2liaWxpdHkgYW5kXG4vLyB0aGVuIHNpbWlsYXJseSBzY2FsZWQgdGhlIGRlZmF1bHQgZm9udC5cbmNvbnN0IGNvbG9ycyA9IHtcbiAgYmFja2dyb3VuZDogXCIjMjgyYzM0XCIsXG4gIGRlZmF1bHQ6IFwiI2M0Y2FkNlwiLFxuICBsaWdodFJlZDogXCIjZTA2Yzc1XCIsXG4gIGJsdWU6IFwiIzYxYWZlZlwiLFxuICBncmF5OiBcIiM4YzkyYTNcIixcbiAgZ3JlZW46IFwiIzk4YzM3OVwiLFxuICBwdXJwbGU6IFwiI2M2NzhkZFwiLFxuICByZWQ6IFwiI2JlNTA0NlwiLFxuICB0ZWFsOiBcIiM1NmI2YzJcIixcbiAgcGVhY2g6IFwiI2QxOWE2NlwiLFxufVxuXG5jb25zdCBydWxlcyA9IChjb2xvcnMpID0+IFtcbiAgeyB0b2tlbjogXCJcIiwgZm9yZWdyb3VuZDogY29sb3JzLmRlZmF1bHQgfSxcbiAgeyB0b2tlbjogXCJ2YXJpYWJsZVwiLCBmb3JlZ3JvdW5kOiBjb2xvcnMubGlnaHRSZWQgfSxcbiAgeyB0b2tlbjogXCJjb25zdGFudFwiLCBmb3JlZ3JvdW5kOiBjb2xvcnMuYmx1ZSB9LFxuICB7IHRva2VuOiBcImNvbnN0YW50LmNoYXJhY3Rlci5lc2NhcGVcIiwgZm9yZWdyb3VuZDogY29sb3JzLmJsdWUgfSxcbiAgeyB0b2tlbjogXCJjb21tZW50XCIsIGZvcmVncm91bmQ6IGNvbG9ycy5ncmF5IH0sXG4gIHsgdG9rZW46IFwibnVtYmVyXCIsIGZvcmVncm91bmQ6IGNvbG9ycy5ibHVlIH0sXG4gIHsgdG9rZW46IFwicmVnZXhwXCIsIGZvcmVncm91bmQ6IGNvbG9ycy5saWdodFJlZCB9LFxuICB7IHRva2VuOiBcInR5cGVcIiwgZm9yZWdyb3VuZDogY29sb3JzLmxpZ2h0UmVkIH0sXG4gIHsgdG9rZW46IFwic3RyaW5nXCIsIGZvcmVncm91bmQ6IGNvbG9ycy5ncmVlbiB9LFxuICB7IHRva2VuOiBcImtleXdvcmRcIiwgZm9yZWdyb3VuZDogY29sb3JzLnB1cnBsZSB9LFxuICB7IHRva2VuOiBcIm9wZXJhdG9yXCIsIGZvcmVncm91bmQ6IGNvbG9ycy5wZWFjaCB9LFxuICB7IHRva2VuOiBcImRlbGltaXRlci5icmFja2V0LmVtYmVkXCIsIGZvcmVncm91bmQ6IGNvbG9ycy5yZWQgfSxcbiAgeyB0b2tlbjogXCJzaWdpbFwiLCBmb3JlZ3JvdW5kOiBjb2xvcnMudGVhbCB9LFxuICB7IHRva2VuOiBcImZ1bmN0aW9uXCIsIGZvcmVncm91bmQ6IGNvbG9ycy5ibHVlIH0sXG4gIHsgdG9rZW46IFwiZnVuY3Rpb24uY2FsbFwiLCBmb3JlZ3JvdW5kOiBjb2xvcnMuZGVmYXVsdCB9LFxuXG4gIC8vIE1hcmtkb3duIHNwZWNpZmljXG4gIHsgdG9rZW46IFwiZW1waGFzaXNcIiwgZm9udFN0eWxlOiBcIml0YWxpY1wiIH0sXG4gIHsgdG9rZW46IFwic3Ryb25nXCIsIGZvbnRTdHlsZTogXCJib2xkXCIgfSxcbiAgeyB0b2tlbjogXCJrZXl3b3JkLm1kXCIsIGZvcmVncm91bmQ6IGNvbG9ycy5saWdodFJlZCB9LFxuICB7IHRva2VuOiBcImtleXdvcmQudGFibGVcIiwgZm9yZWdyb3VuZDogY29sb3JzLmxpZ2h0UmVkIH0sXG4gIHsgdG9rZW46IFwic3RyaW5nLmxpbmsubWRcIiwgZm9yZWdyb3VuZDogY29sb3JzLmJsdWUgfSxcbiAgeyB0b2tlbjogXCJ2YXJpYWJsZS5tZFwiLCBmb3JlZ3JvdW5kOiBjb2xvcnMudGVhbCB9LFxuICB7IHRva2VuOiBcInN0cmluZy5tZFwiLCBmb3JlZ3JvdW5kOiBjb2xvcnMuZGVmYXVsdCB9LFxuICB7IHRva2VuOiBcInZhcmlhYmxlLnNvdXJjZS5tZFwiLCBmb3JlZ3JvdW5kOiBjb2xvcnMuZGVmYXVsdCB9LFxuXG4gIC8vIFhNTCBzcGVjaWZpY1xuICB7IHRva2VuOiBcInRhZ1wiLCBmb3JlZ3JvdW5kOiBjb2xvcnMubGlnaHRSZWQgfSxcbiAgeyB0b2tlbjogXCJtZXRhdGFnXCIsIGZvcmVncm91bmQ6IGNvbG9ycy5saWdodFJlZCB9LFxuICB7IHRva2VuOiBcImF0dHJpYnV0ZS5uYW1lXCIsIGZvcmVncm91bmQ6IGNvbG9ycy5wZWFjaCB9LFxuICB7IHRva2VuOiBcImF0dHJpYnV0ZS52YWx1ZVwiLCBmb3JlZ3JvdW5kOiBjb2xvcnMuZ3JlZW4gfSxcblxuICAvLyBKU09OIHNwZWNpZmljXG4gIHsgdG9rZW46IFwic3RyaW5nLmtleVwiLCBmb3JlZ3JvdW5kOiBjb2xvcnMubGlnaHRSZWQgfSxcbiAgeyB0b2tlbjogXCJrZXl3b3JkLmpzb25cIiwgZm9yZWdyb3VuZDogY29sb3JzLmJsdWUgfSxcblxuICAvLyBTUUwgc3BlY2lmaWNcbiAgeyB0b2tlbjogXCJvcGVyYXRvci5zcWxcIiwgZm9yZWdyb3VuZDogY29sb3JzLnB1cnBsZSB9LFxuXVxuXG5jb25zdCB0aGVtZSA9IHtcbiAgYmFzZTogXCJ2cy1kYXJrXCIsXG4gIGluaGVyaXQ6IGZhbHNlLFxuICBydWxlczogcnVsZXMoY29sb3JzKSxcbiAgY29sb3JzOiB7XG4gICAgXCJlZGl0b3IuYmFja2dyb3VuZFwiOiBjb2xvcnMuYmFja2dyb3VuZCxcbiAgICBcImVkaXRvci5mb3JlZ3JvdW5kXCI6IGNvbG9ycy5kZWZhdWx0LFxuICAgIFwiZWRpdG9yTGluZU51bWJlci5mb3JlZ3JvdW5kXCI6IFwiIzYzNmQ4M1wiLFxuICAgIFwiZWRpdG9yQ3Vyc29yLmZvcmVncm91bmRcIjogXCIjNjM2ZDgzXCIsXG4gICAgXCJlZGl0b3Iuc2VsZWN0aW9uQmFja2dyb3VuZFwiOiBcIiMzZTQ0NTFcIixcbiAgICBcImVkaXRvci5maW5kTWF0Y2hIaWdobGlnaHRCYWNrZ3JvdW5kXCI6IFwiIzUyOGJmZjNkXCIsXG4gICAgXCJlZGl0b3JTdWdnZXN0V2lkZ2V0LmJhY2tncm91bmRcIjogXCIjMjEyNTJiXCIsXG4gICAgXCJlZGl0b3JTdWdnZXN0V2lkZ2V0LmJvcmRlclwiOiBcIiMxODFhMWZcIixcbiAgICBcImVkaXRvclN1Z2dlc3RXaWRnZXQuc2VsZWN0ZWRCYWNrZ3JvdW5kXCI6IFwiIzJjMzEzYVwiLFxuICAgIFwiaW5wdXQuYmFja2dyb3VuZFwiOiBcIiMxYjFkMjNcIixcbiAgICBcImlucHV0LmJvcmRlclwiOiBcIiMxODFhMWZcIixcbiAgICBcImVkaXRvckJyYWNrZXRNYXRjaC5ib3JkZXJcIjogXCIjMjgyYzM0XCIsXG4gICAgXCJlZGl0b3JCcmFja2V0TWF0Y2guYmFja2dyb3VuZFwiOiBcIiMzZTQ0NTFcIixcbiAgfSxcbn1cblxuZXhwb3J0IHsgdGhlbWUgfVxuIiwgIi8vIGh0dHBzOi8vZ2l0aHViLmNvbS9saXZlYm9vay1kZXYvbGl2ZWJvb2svYmxvYi84NTMyYmMzMzRiZGNmM2M1N2ZhYjliNjk0NjY2ZTYwOTg3N2QyNzlmL2Fzc2V0cy9qcy9ob29rcy9jZWxsX2VkaXRvci9saXZlX2VkaXRvci5qc1xuXG5pbXBvcnQgbG9hZGVyIGZyb20gXCJAbW9uYWNvLWVkaXRvci9sb2FkZXJcIlxuaW1wb3J0IHsgdGhlbWUgfSBmcm9tIFwiLi90aGVtZXNcIlxuXG5jbGFzcyBDb2RlRWRpdG9yIHtcbiAgY29uc3RydWN0b3IoZWwsIHBhdGgsIHZhbHVlLCBvcHRzKSB7XG4gICAgdGhpcy5lbCA9IGVsXG4gICAgdGhpcy5wYXRoID0gcGF0aFxuICAgIHRoaXMudmFsdWUgPSB2YWx1ZVxuICAgIHRoaXMub3B0cyA9IG9wdHNcbiAgICAvLyBodHRwczovL21pY3Jvc29mdC5naXRodWIuaW8vbW9uYWNvLWVkaXRvci9kb2NzLmh0bWwjaW50ZXJmYWNlcy9lZGl0b3IuSVN0YW5kYWxvbmVDb2RlRWRpdG9yLmh0bWxcbiAgICB0aGlzLnN0YW5kYWxvbmVfY29kZV9lZGl0b3IgPSBudWxsXG4gICAgdGhpcy5fb25Nb3VudCA9IFtdXG4gIH1cblxuICBpc01vdW50ZWQoKSB7XG4gICAgcmV0dXJuICEhdGhpcy5zdGFuZGFsb25lX2NvZGVfZWRpdG9yXG4gIH1cblxuICBtb3VudCgpIHtcbiAgICBpZiAodGhpcy5pc01vdW50ZWQoKSkge1xuICAgICAgdGhyb3cgbmV3IEVycm9yKFwiVGhlIG1vbmFjbyBlZGl0b3IgaXMgYWxyZWFkeSBtb3VudGVkXCIpXG4gICAgfVxuXG4gICAgdGhpcy5fbW91bnRFZGl0b3IoKVxuICB9XG5cbiAgb25Nb3VudChjYWxsYmFjaykge1xuICAgIHRoaXMuX29uTW91bnQucHVzaChjYWxsYmFjaylcbiAgfVxuXG4gIGRpc3Bvc2UoKSB7XG4gICAgaWYgKHRoaXMuaXNNb3VudGVkKCkpIHtcbiAgICAgIGNvbnN0IG1vZGVsID0gdGhpcy5zdGFuZGFsb25lX2NvZGVfZWRpdG9yLmdldE1vZGVsKClcblxuICAgICAgaWYgKG1vZGVsKSB7XG4gICAgICAgIG1vZGVsLmRpc3Bvc2UoKVxuICAgICAgfVxuXG4gICAgICB0aGlzLnN0YW5kYWxvbmVfY29kZV9lZGl0b3IuZGlzcG9zZSgpXG4gICAgfVxuICB9XG5cbiAgX21vdW50RWRpdG9yKCkge1xuICAgIHRoaXMub3B0cy52YWx1ZSA9IHRoaXMudmFsdWVcblxuICAgIGxvYWRlci5pbml0KCkudGhlbigobW9uYWNvKSA9PiB7XG4gICAgICBtb25hY28uZWRpdG9yLmRlZmluZVRoZW1lKFwiZGVmYXVsdFwiLCB0aGVtZSlcblxuICAgICAgbGV0IG1vZGVsVXJpID0gbW9uYWNvLlVyaS5wYXJzZSh0aGlzLnBhdGgpXG4gICAgICBsZXQgbGFuZ3VhZ2UgPSB0aGlzLm9wdHMubGFuZ3VhZ2VcbiAgICAgIGxldCBtb2RlbCA9IG1vbmFjby5lZGl0b3IuY3JlYXRlTW9kZWwodGhpcy52YWx1ZSwgbGFuZ3VhZ2UsIG1vZGVsVXJpKVxuXG4gICAgICB0aGlzLm9wdHMubGFuZ3VhZ2UgPSB1bmRlZmluZWRcbiAgICAgIHRoaXMub3B0cy5tb2RlbCA9IG1vZGVsXG4gICAgICB0aGlzLnN0YW5kYWxvbmVfY29kZV9lZGl0b3IgPSBtb25hY28uZWRpdG9yLmNyZWF0ZSh0aGlzLmVsLCB0aGlzLm9wdHMpXG5cbiAgICAgIHRoaXMuX29uTW91bnQuZm9yRWFjaCgoY2FsbGJhY2spID0+IGNhbGxiYWNrKG1vbmFjbykpXG4gICAgfSlcbiAgfVxufVxuXG5leHBvcnQgZGVmYXVsdCBDb2RlRWRpdG9yXG4iLCAiaW1wb3J0IENvZGVFZGl0b3IgZnJvbSBcIi4uL2VkaXRvci9jb2RlX2VkaXRvclwiXG5cbmNvbnN0IENvZGVFZGl0b3JIb29rID0ge1xuICBtb3VudGVkKCkge1xuICAgIC8vIFRPRE86IHZhbGlkYXRlIGRhdGFzZXRcbiAgICBjb25zdCBvcHRzID0gSlNPTi5wYXJzZSh0aGlzLmVsLmRhdGFzZXQub3B0cylcbiAgICB0aGlzLmNvZGVFZGl0b3IgPSBuZXcgQ29kZUVkaXRvcihcbiAgICAgIHRoaXMuZWwsXG4gICAgICB0aGlzLmVsLmRhdGFzZXQucGF0aCxcbiAgICAgIHRoaXMuZWwuZGF0YXNldC52YWx1ZSxcbiAgICAgIG9wdHNcbiAgICApXG5cbiAgICB0aGlzLmNvZGVFZGl0b3Iub25Nb3VudCgobW9uYWNvKSA9PiB7XG4gICAgICB0aGlzLmVsLmRpc3BhdGNoRXZlbnQoXG4gICAgICAgIG5ldyBDdXN0b21FdmVudChcImxtZTplZGl0b3JfbW91bnRlZFwiLCB7XG4gICAgICAgICAgZGV0YWlsOiB7IGhvb2s6IHRoaXMsIGVkaXRvcjogdGhpcy5jb2RlRWRpdG9yIH0sXG4gICAgICAgICAgYnViYmxlczogdHJ1ZSxcbiAgICAgICAgfSlcbiAgICAgIClcblxuICAgICAgdGhpcy5oYW5kbGVFdmVudChcbiAgICAgICAgXCJsbWU6Y2hhbmdlX2xhbmd1YWdlOlwiICsgdGhpcy5lbC5kYXRhc2V0LnBhdGgsXG4gICAgICAgIChkYXRhKSA9PiB7XG4gICAgICAgICAgY29uc3QgbW9kZWwgPSB0aGlzLmNvZGVFZGl0b3Iuc3RhbmRhbG9uZV9jb2RlX2VkaXRvci5nZXRNb2RlbCgpXG5cbiAgICAgICAgICBpZiAobW9kZWwuZ2V0TGFuZ3VhZ2VJZCgpICE9PSBkYXRhLm1pbWVUeXBlT3JMYW5ndWFnZUlkKSB7XG4gICAgICAgICAgICBtb25hY28uZWRpdG9yLnNldE1vZGVsTGFuZ3VhZ2UobW9kZWwsIGRhdGEubWltZVR5cGVPckxhbmd1YWdlSWQpXG4gICAgICAgICAgfVxuICAgICAgICB9XG4gICAgICApXG5cbiAgICAgIHRoaXMuaGFuZGxlRXZlbnQoXCJsbWU6c2V0X3ZhbHVlOlwiICsgdGhpcy5lbC5kYXRhc2V0LnBhdGgsIChkYXRhKSA9PiB7XG4gICAgICAgIHRoaXMuY29kZUVkaXRvci5zdGFuZGFsb25lX2NvZGVfZWRpdG9yLnNldFZhbHVlKGRhdGEudmFsdWUpXG4gICAgICB9KVxuXG4gICAgICB0aGlzLmVsLnF1ZXJ5U2VsZWN0b3JBbGwoXCJ0ZXh0YXJlYVwiKS5mb3JFYWNoKCh0ZXh0YXJlYSkgPT4ge1xuICAgICAgICB0ZXh0YXJlYS5zZXRBdHRyaWJ1dGUoXG4gICAgICAgICAgXCJuYW1lXCIsXG4gICAgICAgICAgXCJsaXZlX21vbmFjb19lZGl0b3JbXCIgKyB0aGlzLmVsLmRhdGFzZXQucGF0aCArIFwiXVwiXG4gICAgICAgIClcbiAgICAgIH0pXG5cbiAgICAgIHRoaXMuZWwucmVtb3ZlQXR0cmlidXRlKFwiZGF0YS12YWx1ZVwiKVxuICAgICAgdGhpcy5lbC5yZW1vdmVBdHRyaWJ1dGUoXCJkYXRhLW9wdHNcIilcbiAgICB9KVxuXG4gICAgaWYgKCF0aGlzLmNvZGVFZGl0b3IuaXNNb3VudGVkKCkpIHtcbiAgICAgIHRoaXMuY29kZUVkaXRvci5tb3VudCgpXG4gICAgfVxuICB9LFxuXG4gIGRlc3Ryb3llZCgpIHtcbiAgICBpZiAodGhpcy5jb2RlRWRpdG9yKSB7XG4gICAgICB0aGlzLmNvZGVFZGl0b3IuZGlzcG9zZSgpXG4gICAgfVxuICB9LFxufVxuXG5leHBvcnQgeyBDb2RlRWRpdG9ySG9vayB9XG4iLCAiLy8gQmVhY29uIEFkbWluXG4vL1xuLy8gTm90ZTpcbi8vIDEuIHJ1biBgbWl4IGFzc2V0cy5idWlsZGAgdG8gZGlzdHJpYnV0ZSB1cGRhdGVkIHN0YXRpYyBhc3NldHNcbi8vIDIuIHBob2VuaXgganMgbG9hZGVkIGZyb20gdGhlIGhvc3QgYXBwbGljYXRpb25cblxuaW1wb3J0IHsgQ29kZUVkaXRvckhvb2sgfSBmcm9tIFwiLi4vLi4vZGVwcy9saXZlX21vbmFjb19lZGl0b3IvcHJpdi9zdGF0aWMvbGl2ZV9tb25hY29fZWRpdG9yLmVzbVwiXG5cbmxldCBIb29rcyA9IHt9XG5Ib29rcy5Db2RlRWRpdG9ySG9vayA9IENvZGVFZGl0b3JIb29rXG5cbndpbmRvdy5hZGRFdmVudExpc3RlbmVyKFwibG1lOmVkaXRvcl9tb3VudGVkXCIsIChldikgPT4ge1xuICBjb25zdCBob29rID0gZXYuZGV0YWlsLmhvb2tcbiAgY29uc3QgZWRpdG9yID0gZXYuZGV0YWlsLmVkaXRvci5zdGFuZGFsb25lX2NvZGVfZWRpdG9yXG4gIGNvbnN0IGV2ZW50TmFtZSA9IGV2LmRldGFpbC5lZGl0b3IucGF0aCArIFwiX2VkaXRvcl9sb3N0X2ZvY3VzXCJcblxuICBlZGl0b3Iub25EaWRCbHVyRWRpdG9yV2lkZ2V0KCgpID0+IHtcbiAgICBob29rLnB1c2hFdmVudChldmVudE5hbWUsIHsgdmFsdWU6IGVkaXRvci5nZXRWYWx1ZSgpIH0pXG4gIH0pXG59KVxuXG53aW5kb3cuYWRkRXZlbnRMaXN0ZW5lcihcImJlYWNvbl9hZG1pbjpjbGlwY29weVwiLCAoZXZlbnQpID0+IHtcbiAgY29uc3QgcmVzdWx0X2lkID0gYCR7ZXZlbnQudGFyZ2V0LmlkfS1jb3B5LXRvLWNsaXBib2FyZC1yZXN1bHRgXG4gIGNvbnN0IGVsID0gZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQocmVzdWx0X2lkKTtcblxuICBpZiAoXCJjbGlwYm9hcmRcIiBpbiBuYXZpZ2F0b3IpIHtcbiAgICBpZiAoZXZlbnQudGFyZ2V0LnRhZ05hbWUgPT09IFwiSU5QVVRcIikge1xuICAgICAgdHh0ID0gZXZlbnQudGFyZ2V0LnZhbHVlO1xuICAgIH0gZWxzZSB7XG4gICAgICB0eHQgPSBldmVudC50YXJnZXQudGV4dENvbnRlbnQ7XG4gICAgfVxuXG4gICAgbmF2aWdhdG9yLmNsaXBib2FyZC53cml0ZVRleHQodHh0KS50aGVuKCgpID0+IHtcbiAgICAgIGVsLmlubmVyVGV4dCA9ICdDb3BpZWQgdG8gY2xpcGJvYXJkJztcbiAgICAgIC8vIE1ha2UgaXQgdmlzaWJsZVxuICAgICAgZWwuY2xhc3NMaXN0LnJlbW92ZSgnaW52aXNpYmxlJywgJ3RleHQtcmVkLTUwMCcsICdvcGFjaXR5LTAnKTtcbiAgICAgIC8vIEZhZGUgaW4gYW5kIHRyYW5zbGF0ZSB1cHdhcmRzXG4gICAgICBlbC5jbGFzc0xpc3QuYWRkKCd0ZXh0LWdyZWVuLTUwMCcsICdvcGFjaXR5LTEwMCcsICctdHJhbnNsYXRlLXktMicpO1xuXG4gICAgICBzZXRUaW1lb3V0KGZ1bmN0aW9uICgpIHtcbiAgICAgICAgZWwuY2xhc3NMaXN0LnJlbW92ZSgndGV4dC1ncmVlbi01MDAnLCAnb3BhY2l0eS0xMDAnLCAnLXRyYW5zbGF0ZS15LTInKTtcbiAgICAgICAgZWwuY2xhc3NMaXN0LmFkZCgnaW52aXNpYmxlJywgJ3RleHQtcmVkLTUwMCcsICdvcGFjaXR5LTAnKTtcbiAgICAgIH0sIDIwMDApO1xuXG4gICAgfSkuY2F0Y2goKCkgPT4ge1xuICAgICAgZWwuaW5uZXJUZXh0ID0gJ0NvdWxkIG5vdCBjb3B5JztcbiAgICAgIC8vIE1ha2UgaXQgdmlzaWJsZVxuICAgICAgZWwuY2xhc3NMaXN0LnJlbW92ZSgnaW52aXNpYmxlJywgJ3RleHQtZ3JlZW4tNTAwJywgJ29wYWNpdHktMCcpO1xuICAgICAgLy8gRmFkZSBpbiBhbmQgdHJhbnNsYXRlIHVwd2FyZHNcbiAgICAgIGVsLmNsYXNzTGlzdC5hZGQoJ3RleHQtcmVkLTUwMCcsICdvcGFjaXR5LTEwMCcsICctdHJhbnNsYXRlLXktMicpO1xuICAgIH0pXG4gIH0gZWxzZSB7XG4gICAgYWxlcnQoXG4gICAgICBcIlNvcnJ5LCB5b3VyIGJyb3dzZXIgZG9lcyBub3Qgc3VwcG9ydCBjbGlwYm9hcmQgY29weS5cIlxuICAgICk7XG4gIH1cbn0pO1xuXG5sZXQgc29ja2V0UGF0aCA9XG4gIGRvY3VtZW50LnF1ZXJ5U2VsZWN0b3IoXCJodG1sXCIpLmdldEF0dHJpYnV0ZShcInBoeC1zb2NrZXRcIikgfHwgXCIvbGl2ZVwiXG5sZXQgY3NyZlRva2VuID0gZG9jdW1lbnRcbiAgLnF1ZXJ5U2VsZWN0b3IoXCJtZXRhW25hbWU9J2NzcmYtdG9rZW4nXVwiKVxuICAuZ2V0QXR0cmlidXRlKFwiY29udGVudFwiKVxubGV0IGxpdmVTb2NrZXQgPSBuZXcgTGl2ZVZpZXcuTGl2ZVNvY2tldChzb2NrZXRQYXRoLCBQaG9lbml4LlNvY2tldCwge1xuICBob29rczogSG9va3MsXG4gIHBhcmFtczogeyBfY3NyZl90b2tlbjogY3NyZlRva2VuIH0sXG59KVxubGl2ZVNvY2tldC5jb25uZWN0KClcbndpbmRvdy5saXZlU29ja2V0ID0gbGl2ZVNvY2tldFxuIl0sCiAgIm1hcHBpbmdzIjogIjs7QUFBQSxXQUFTLGdCQUFnQixLQUFLLEtBQUssT0FBTztBQUN4QyxRQUFJLE9BQU8sS0FBSztBQUNkLGFBQU8sZUFBZSxLQUFLLEtBQUs7UUFDOUI7UUFDQSxZQUFZO1FBQ1osY0FBYztRQUNkLFVBQVU7TUFDWixDQUFDO0lBQ0gsT0FBTztBQUNMLFVBQUksR0FBRyxJQUFJO0lBQ2I7QUFFQSxXQUFPO0VBQ1Q7QUFFQSxXQUFTLFFBQVEsUUFBUSxnQkFBZ0I7QUFDdkMsUUFBSSxPQUFPLE9BQU8sS0FBSyxNQUFNO0FBRTdCLFFBQUksT0FBTyx1QkFBdUI7QUFDaEMsVUFBSSxVQUFVLE9BQU8sc0JBQXNCLE1B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QUFFMUMsV0FBTyxzQkFBc0IsTUFBTTtBQUNqQyxXQUFLLFVBQVUsV0FBVyxFQUFFLE9BQU8sT0FBTyxTQUFTLEVBQUUsQ0FBQztBQUFBLElBQ3hELENBQUM7QUFBQSxFQUNILENBQUM7QUFFRCxTQUFPLGlCQUFpQix5QkFBeUIsQ0FBQyxVQUFVO0FBQzFELFVBQU0sWUFBWSxHQUFHLE1BQU0sT0FBTztBQUNsQyxVQUFNLEtBQUssU0FBUyxlQUFlLFNBQVM7QUFFNUMsUUFBSSxlQUFlLFdBQVc7QUFDNUIsVUFBSSxNQUFNLE9BQU8sWUFBWSxTQUFTO0FBQ3BDLGNBQU0sTUFBTSxPQUFPO0FBQUEsTUFDckIsT0FBTztBQUNMLGNBQU0sTUFBTSxPQUFPO0FBQUEsTUFDckI7QUFFQSxnQkFBVSxVQUFVLFVBQVUsR0FBRyxFQUFFLEtBQUssTUFBTTtBQUM1QyxXQUFHLFlBQVk7QUFFZixXQUFHLFVBQVUsT0FBTyxhQUFhLGdCQUFnQixXQUFXO0FBRTVELFdBQUcsVUFBVSxJQUFJLGtCQUFrQixlQUFlLGdCQUFnQjtBQUVsRSxtQkFBVyxXQUFZO0FBQ3JCLGFBQUcsVUFBVSxPQUFPLGtCQUFrQixlQUFlLGdCQUFnQjtBQUNyRSxhQUFHLFVBQVUsSUFBSSxhQUFhLGdCQUFnQixXQUFXO0FBQUEsUUFDM0QsR0FBRyxHQUFJO0FBQUEsTUFFVCxDQUFDLEVBQUUsTUFBTSxNQUFNO0FBQ2IsV0FBRyxZQUFZO0FBRWYsV0FBRyxVQUFVLE9BQU8sYUFBYSxrQkFBa0IsV0FBVztBQUU5RCxXQUFHLFVBQVUsSUFBSSxnQkFBZ0IsZUFBZSxnQkFBZ0I7QUFBQSxNQUNsRSxDQUFDO0FBQUEsSUFDSCxPQUFPO0FBQ0w7QUFBQSxRQUNFO0FBQUEsTUFDRjtBQUFBLElBQ0Y7QUFBQSxFQUNGLENBQUM7QUFFRCxNQUFJLGFBQ0YsU0FBUyxjQUFjLE1BQU0sRUFBRSxhQUFhLFlBQVksS0FBSztBQUMvRCxNQUFJLFlBQVksU0FDYixjQUFjLHlCQUF5QixFQUN2QyxhQUFhLFNBQVM7QUFDekIsTUFBSSxhQUFhLElBQUksU0FBUyxXQUFXLFlBQVksUUFBUSxRQUFRO0FBQUEsSUFDbkUsT0FBTztBQUFBLElBQ1AsUUFBUSxFQUFFLGFBQWEsVUFBVTtBQUFBLEVBQ25DLENBQUM7QUFDRCxhQUFXLFFBQVE7QUFDbkIsU0FBTyxhQUFhOyIsCiAgIm5hbWVzIjogWyJfZGVmaW5lUHJvcGVydHkiLCAib3duS2V5cyIsICJfb2JqZWN0U3ByZWFkMiIsICJlcnJvck1lc3NhZ2VzIiwgImdldFN0YXRlIiwgInN0YXRlIiwgInNldFN0YXRlIiwgImN1cnJ5IiwgImlzT2JqZWN0IiwgImNvbmZpZyIsICJlcnJvckhhbmRsZXIiLCAidGhyb3dFcnJvciIsICJ2YWxpZGF0b3JzIiwgImNvbXBvc2UiLCAiY29uZmlndXJlTG9hZGVyIiwgInJlcXVpcmUiLCAiY29sb3JzIl0KfQo=
