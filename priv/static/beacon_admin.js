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
  var socketPath = document.querySelector("html").getAttribute("phx-socket") || "/live";
  var csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
  var liveSocket = new LiveView.LiveSocket(socketPath, Phoenix.Socket, {
    hooks: Hooks,
    params: { _csrf_token: csrfToken }
  });
  liveSocket.connect();
  window.liveSocket = liveSocket;
})();
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsiLi4vLi4vZGVwcy9saXZlX21vbmFjb19lZGl0b3IvYXNzZXRzL25vZGVfbW9kdWxlcy9AbW9uYWNvLWVkaXRvci9sb2FkZXIvbGliL2VzL192aXJ0dWFsL19yb2xsdXBQbHVnaW5CYWJlbEhlbHBlcnMuanMiLCAiLi4vLi4vZGVwcy9saXZlX21vbmFjb19lZGl0b3IvYXNzZXRzL25vZGVfbW9kdWxlcy9zdGF0ZS1sb2NhbC9saWIvZXMvc3RhdGUtbG9jYWwuanMiLCAiLi4vLi4vZGVwcy9saXZlX21vbmFjb19lZGl0b3IvYXNzZXRzL25vZGVfbW9kdWxlcy9AbW9uYWNvLWVkaXRvci9sb2FkZXIvbGliL2VzL2NvbmZpZy9pbmRleC5qcyIsICIuLi8uLi9kZXBzL2xpdmVfbW9uYWNvX2VkaXRvci9hc3NldHMvbm9kZV9tb2R1bGVzL0Btb25hY28tZWRpdG9yL2xvYWRlci9saWIvZXMvdXRpbHMvY3VycnkuanMiLCAiLi4vLi4vZGVwcy9saXZlX21vbmFjb19lZGl0b3IvYXNzZXRzL25vZGVfbW9kdWxlcy9AbW9uYWNvLWVkaXRvci9sb2FkZXIvbGliL2VzL3V0aWxzL2lzT2JqZWN0LmpzIiwgIi4uLy4uL2RlcHMvbGl2ZV9tb25hY29fZWRpdG9yL2Fzc2V0cy9ub2RlX21vZHVsZXMvQG1vbmFjby1lZGl0b3IvbG9hZGVyL2xpYi9lcy92YWxpZGF0b3JzL2luZGV4LmpzIiwgIi4uLy4uL2RlcHMvbGl2ZV9tb25hY29fZWRpdG9yL2Fzc2V0cy9ub2RlX21vZHVsZXMvQG1vbmFjby1lZGl0b3IvbG9hZGVyL2xpYi9lcy91dGlscy9jb21wb3NlLmpzIiwgIi4uLy4uL2RlcHMvbGl2ZV9tb25hY29fZWRpdG9yL2Fzc2V0cy9ub2RlX21vZHVsZXMvQG1vbmFjby1lZGl0b3IvbG9hZGVyL2xpYi9lcy91dGlscy9kZWVwTWVyZ2UuanMiLCAiLi4vLi4vZGVwcy9saXZlX21vbmFjb19lZGl0b3IvYXNzZXRzL25vZGVfbW9kdWxlcy9AbW9uYWNvLWVkaXRvci9sb2FkZXIvbGliL2VzL3V0aWxzL21ha2VDYW5jZWxhYmxlLmpzIiwgIi4uLy4uL2RlcHMvbGl2ZV9tb25hY29fZWRpdG9yL2Fzc2V0cy9ub2RlX21vZHVsZXMvQG1vbmFjby1lZGl0b3IvbG9hZGVyL2xpYi9lcy9sb2FkZXIvaW5kZXguanMiLCAiLi4vLi4vZGVwcy9saXZlX21vbmFjb19lZGl0b3IvYXNzZXRzL2pzL2xpdmVfbW9uYWNvX2VkaXRvci9lZGl0b3IvY29kZV9lZGl0b3IuanMiLCAiLi4vLi4vZGVwcy9saXZlX21vbmFjb19lZGl0b3IvYXNzZXRzL2pzL2xpdmVfbW9uYWNvX2VkaXRvci9ob29rcy9jb2RlX2VkaXRvci5qcyIsICIuLi8uLi9hc3NldHMvanMvYmVhY29uX2FkbWluLmpzIl0sCiAgInNvdXJjZXNDb250ZW50IjogWyJmdW5jdGlvbiBfZGVmaW5lUHJvcGVydHkob2JqLCBrZXksIHZhbHVlKSB7XG4gIGlmIChrZXkgaW4gb2JqKSB7XG4gICAgT2JqZWN0LmRlZmluZVByb3BlcnR5KG9iaiwga2V5LCB7XG4gICAgICB2YWx1ZTogdmFsdWUsXG4gICAgICBlbnVtZXJhYmxlOiB0cnVlLFxuICAgICAgY29uZmlndXJhYmxlOiB0cnVlLFxuICAgICAgd3JpdGFibGU6IHRydWVcbiAgICB9KTtcbiAgfSBlbHNlIHtcbiAgICBvYmpba2V5XSA9IHZhbHVlO1xuICB9XG5cbiAgcmV0dXJuIG9iajtcbn1cblxuZnVuY3Rpb24gb3duS2V5cyhvYmplY3QsIGVudW1lcmFibGVPbmx5KSB7XG4gIHZhciBrZXlzID0gT2JqZWN0LmtleXMob2JqZWN0KTtcblxuICBpZiAoT2JqZWN0LmdldE93blByb3BlcnR5U3ltYm9scykge1xuICAgIHZhciBzeW1ib2xzID0gT2JqZWN0LmdldE93blByb3BlcnR5U3ltYm9scyhvYmplY3QpO1xuICAgIGlmIChlbnVtZXJhYmxlT25seSkgc3ltYm9scyA9IHN5bWJvbHMuZmlsdGVyKGZ1bmN0aW9uIChzeW0pIHtcbiAgICAgIHJldHVybiBPYmplY3QuZ2V0T3duUHJvcGVydHlEZXNjcmlwdG9yKG9iamVjdCwgc3ltKS5lbnVtZXJhYmxlO1xuICAgIH0pO1xuICAgIGtleXMucHVzaC5hcHBseShrZXlzLCBzeW1ib2xzKTtcbiAgfVxuXG4gIHJldHVybiBrZXlzO1xufVxuXG5mdW5jdGlvbiBfb2JqZWN0U3ByZWFkMih0YXJnZXQpIHtcbiAgZm9yICh2YXIgaSA9IDE7IGkgPCBhcmd1bWVudHMubGVuZ3RoOyBpKyspIHtcbiAgICB2YXIgc291cmNlID0gYXJndW1lbnRzW2ldICE9IG51bGwgPyBhcmd1bWVudHNbaV0gOiB7fTtcblxuICAgIGlmIChpICUgMikge1xuICAgICAgb3duS2V5cyhPYmplY3Qoc291cmNlKSwgdHJ1ZSkuZm9yRWFjaChmdW5jdGlvbiAoa2V5KSB7XG4gICAgICAgIF9kZWZpbmVQcm9wZXJ0eSh0YXJnZXQsIGtleSwgc291cmNlW2tleV0pO1xuICAgICAgfSk7XG4gICAgfSBlbHNlIGlmIChPYmplY3QuZ2V0T3duUHJvcGVydHlEZXNjcmlwdG9ycykge1xuICAgICAgT2JqZWN0LmRlZmluZVByb3BlcnRpZXModGFyZ2V0LCBPYmplY3QuZ2V0T3duUHJvcGVydHlEZXNjcmlwdG9ycyhzb3VyY2UpKTtcbiAgICB9IGVsc2Uge1xuICAgICAgb3duS2V5cyhPYmplY3Qoc291cmNlKSkuZm9yRWFjaChmdW5jdGlvbiAoa2V5KSB7XG4gICAgICAgIE9iamVjdC5kZWZpbmVQcm9wZXJ0eSh0YXJnZXQsIGtleSwgT2JqZWN0LmdldE93blByb3BlcnR5RGVzY3JpcHRvcihzb3VyY2UsIGtleSkpO1xuICAgICAgfSk7XG4gICAgfVxuICB9XG5cbiAgcmV0dXJuIHRhcmdldDtcbn1cblxuZnVuY3Rpb24gX29iamVjdFdpdGhvdXRQcm9wZXJ0aWVzTG9vc2Uoc291cmNlLCBleGNsdWRlZCkge1xuICBpZiAoc291cmNlID09IG51bGwpIHJldHVybiB7fTtcbiAgdmFyIHRhcmdldCA9IHt9O1xuICB2YXIgc291cmNlS2V5cyA9IE9iamVjdC5rZXlzKHNvdXJjZSk7XG4gIHZhciBrZXksIGk7XG5cbiAgZm9yIChpID0gMDsgaSA8IHNvdXJjZUtleXMubGVuZ3RoOyBpKyspIHtcbiAgICBrZXkgPSBzb3VyY2VLZXlzW2ldO1xuICAgIGlmIChleGNsdWRlZC5pbmRleE9mKGtleSkgPj0gMCkgY29udGludWU7XG4gICAgdGFyZ2V0W2tleV0gPSBzb3VyY2Vba2V5XTtcbiAgfVxuXG4gIHJldHVybiB0YXJnZXQ7XG59XG5cbmZ1bmN0aW9uIF9vYmplY3RXaXRob3V0UHJvcGVydGllcyhzb3VyY2UsIGV4Y2x1ZGVkKSB7XG4gIGlmIChzb3VyY2UgPT0gbnVsbCkgcmV0dXJuIHt9O1xuXG4gIHZhciB0YXJnZXQgPSBfb2JqZWN0V2l0aG91dFByb3BlcnRpZXNMb29zZShzb3VyY2UsIGV4Y2x1ZGVkKTtcblxuICB2YXIga2V5LCBpO1xuXG4gIGlmIChPYmplY3QuZ2V0T3duUHJvcGVydHlTeW1ib2xzKSB7XG4gICAgdmFyIHNvdXJjZVN5bWJvbEtleXMgPSBPYmplY3QuZ2V0T3duUHJvcGVydHlTeW1ib2xzKHNvdXJjZSk7XG5cbiAgICBmb3IgKGkgPSAwOyBpIDwgc291cmNlU3ltYm9sS2V5cy5sZW5ndGg7IGkrKykge1xuICAgICAga2V5ID0gc291cmNlU3ltYm9sS2V5c1tpXTtcbiAgICAgIGlmIChleGNsdWRlZC5pbmRleE9mKGtleSkgPj0gMCkgY29udGludWU7XG4gICAgICBpZiAoIU9iamVjdC5wcm90b3R5cGUucHJvcGVydHlJc0VudW1lcmFibGUuY2FsbChzb3VyY2UsIGtleSkpIGNvbnRpbnVlO1xuICAgICAgdGFyZ2V0W2tleV0gPSBzb3VyY2Vba2V5XTtcbiAgICB9XG4gIH1cblxuICByZXR1cm4gdGFyZ2V0O1xufVxuXG5mdW5jdGlvbiBfc2xpY2VkVG9BcnJheShhcnIsIGkpIHtcbiAgcmV0dXJuIF9hcnJheVdpdGhIb2xlcyhhcnIpIHx8IF9pdGVyYWJsZVRvQXJyYXlMaW1pdChhcnIsIGkpIHx8IF91bnN1cHBvcnRlZEl0ZXJhYmxlVG9BcnJheShhcnIsIGkpIHx8IF9ub25JdGVyYWJsZVJlc3QoKTtcbn1cblxuZnVuY3Rpb24gX2FycmF5V2l0aEhvbGVzKGFycikge1xuICBpZiAoQXJyYXkuaXNBcnJheShhcnIpKSByZXR1cm4gYXJyO1xufVxuXG5mdW5jdGlvbiBfaXRlcmFibGVUb0FycmF5TGltaXQoYXJyLCBpKSB7XG4gIGlmICh0eXBlb2YgU3ltYm9sID09PSBcInVuZGVmaW5lZFwiIHx8ICEoU3ltYm9sLml0ZXJhdG9yIGluIE9iamVjdChhcnIpKSkgcmV0dXJuO1xuICB2YXIgX2FyciA9IFtdO1xuICB2YXIgX24gPSB0cnVlO1xuICB2YXIgX2QgPSBmYWxzZTtcbiAgdmFyIF9lID0gdW5kZWZpbmVkO1xuXG4gIHRyeSB7XG4gICAgZm9yICh2YXIgX2kgPSBhcnJbU3ltYm9sLml0ZXJhdG9yXSgpLCBfczsgIShfbiA9IChfcyA9IF9pLm5leHQoKSkuZG9uZSk7IF9uID0gdHJ1ZSkge1xuICAgICAgX2Fyci5wdXNoKF9zLnZhbHVlKTtcblxuICAgICAgaWYgKGkgJiYgX2Fyci5sZW5ndGggPT09IGkpIGJyZWFrO1xuICAgIH1cbiAgfSBjYXRjaCAoZXJyKSB7XG4gICAgX2QgPSB0cnVlO1xuICAgIF9lID0gZXJyO1xuICB9IGZpbmFsbHkge1xuICAgIHRyeSB7XG4gICAgICBpZiAoIV9uICYmIF9pW1wicmV0dXJuXCJdICE9IG51bGwpIF9pW1wicmV0dXJuXCJdKCk7XG4gICAgfSBmaW5hbGx5IHtcbiAgICAgIGlmIChfZCkgdGhyb3cgX2U7XG4gICAgfVxuICB9XG5cbiAgcmV0dXJuIF9hcnI7XG59XG5cbmZ1bmN0aW9uIF91bnN1cHBvcnRlZEl0ZXJhYmxlVG9BcnJheShvLCBtaW5MZW4pIHtcbiAgaWYgKCFvKSByZXR1cm47XG4gIGlmICh0eXBlb2YgbyA9PT0gXCJzdHJpbmdcIikgcmV0dXJuIF9hcnJheUxpa2VUb0FycmF5KG8sIG1pbkxlbik7XG4gIHZhciBuID0gT2JqZWN0LnByb3RvdHlwZS50b1N0cmluZy5jYWxsKG8pLnNsaWNlKDgsIC0xKTtcbiAgaWYgKG4gPT09IFwiT2JqZWN0XCIgJiYgby5jb25zdHJ1Y3RvcikgbiA9IG8uY29uc3RydWN0b3IubmFtZTtcbiAgaWYgKG4gPT09IFwiTWFwXCIgfHwgbiA9PT0gXCJTZXRcIikgcmV0dXJuIEFycmF5LmZyb20obyk7XG4gIGlmIChuID09PSBcIkFyZ3VtZW50c1wiIHx8IC9eKD86VWl8SSludCg/Ojh8MTZ8MzIpKD86Q2xhbXBlZCk/QXJyYXkkLy50ZXN0KG4pKSByZXR1cm4gX2FycmF5TGlrZVRvQXJyYXkobywgbWluTGVuKTtcbn1cblxuZnVuY3Rpb24gX2FycmF5TGlrZVRvQXJyYXkoYXJyLCBsZW4pIHtcbiAgaWYgKGxlbiA9PSBudWxsIHx8IGxlbiA+IGFyci5sZW5ndGgpIGxlbiA9IGFyci5sZW5ndGg7XG5cbiAgZm9yICh2YXIgaSA9IDAsIGFycjIgPSBuZXcgQXJyYXkobGVuKTsgaSA8IGxlbjsgaSsrKSBhcnIyW2ldID0gYXJyW2ldO1xuXG4gIHJldHVybiBhcnIyO1xufVxuXG5mdW5jdGlvbiBfbm9uSXRlcmFibGVSZXN0KCkge1xuICB0aHJvdyBuZXcgVHlwZUVycm9yKFwiSW52YWxpZCBhdHRlbXB0IHRvIGRlc3RydWN0dXJlIG5vbi1pdGVyYWJsZSBpbnN0YW5jZS5cXG5JbiBvcmRlciB0byBiZSBpdGVyYWJsZSwgbm9uLWFycmF5IG9iamVjdHMgbXVzdCBoYXZlIGEgW1N5bWJvbC5pdGVyYXRvcl0oKSBtZXRob2QuXCIpO1xufVxuXG5leHBvcnQgeyBfYXJyYXlMaWtlVG9BcnJheSBhcyBhcnJheUxpa2VUb0FycmF5LCBfYXJyYXlXaXRoSG9sZXMgYXMgYXJyYXlXaXRoSG9sZXMsIF9kZWZpbmVQcm9wZXJ0eSBhcyBkZWZpbmVQcm9wZXJ0eSwgX2l0ZXJhYmxlVG9BcnJheUxpbWl0IGFzIGl0ZXJhYmxlVG9BcnJheUxpbWl0LCBfbm9uSXRlcmFibGVSZXN0IGFzIG5vbkl0ZXJhYmxlUmVzdCwgX29iamVjdFNwcmVhZDIgYXMgb2JqZWN0U3ByZWFkMiwgX29iamVjdFdpdGhvdXRQcm9wZXJ0aWVzIGFzIG9iamVjdFdpdGhvdXRQcm9wZXJ0aWVzLCBfb2JqZWN0V2l0aG91dFByb3BlcnRpZXNMb29zZSBhcyBvYmplY3RXaXRob3V0UHJvcGVydGllc0xvb3NlLCBfc2xpY2VkVG9BcnJheSBhcyBzbGljZWRUb0FycmF5LCBfdW5zdXBwb3J0ZWRJdGVyYWJsZVRvQXJyYXkgYXMgdW5zdXBwb3J0ZWRJdGVyYWJsZVRvQXJyYXkgfTtcbiIsICJmdW5jdGlvbiBfZGVmaW5lUHJvcGVydHkob2JqLCBrZXksIHZhbHVlKSB7XG4gIGlmIChrZXkgaW4gb2JqKSB7XG4gICAgT2JqZWN0LmRlZmluZVByb3BlcnR5KG9iaiwga2V5LCB7XG4gICAgICB2YWx1ZTogdmFsdWUsXG4gICAgICBlbnVtZXJhYmxlOiB0cnVlLFxuICAgICAgY29uZmlndXJhYmxlOiB0cnVlLFxuICAgICAgd3JpdGFibGU6IHRydWVcbiAgICB9KTtcbiAgfSBlbHNlIHtcbiAgICBvYmpba2V5XSA9IHZhbHVlO1xuICB9XG5cbiAgcmV0dXJuIG9iajtcbn1cblxuZnVuY3Rpb24gb3duS2V5cyhvYmplY3QsIGVudW1lcmFibGVPbmx5KSB7XG4gIHZhciBrZXlzID0gT2JqZWN0LmtleXMob2JqZWN0KTtcblxuICBpZiAoT2JqZWN0LmdldE93blByb3BlcnR5U3ltYm9scykge1xuICAgIHZhciBzeW1ib2xzID0gT2JqZWN0LmdldE93blByb3BlcnR5U3ltYm9scyhvYmplY3QpO1xuICAgIGlmIChlbnVtZXJhYmxlT25seSkgc3ltYm9scyA9IHN5bWJvbHMuZmlsdGVyKGZ1bmN0aW9uIChzeW0pIHtcbiAgICAgIHJldHVybiBPYmplY3QuZ2V0T3duUHJvcGVydHlEZXNjcmlwdG9yKG9iamVjdCwgc3ltKS5lbnVtZXJhYmxlO1xuICAgIH0pO1xuICAgIGtleXMucHVzaC5hcHBseShrZXlzLCBzeW1ib2xzKTtcbiAgfVxuXG4gIHJldHVybiBrZXlzO1xufVxuXG5mdW5jdGlvbiBfb2JqZWN0U3ByZWFkMih0YXJnZXQpIHtcbiAgZm9yICh2YXIgaSA9IDE7IGkgPCBhcmd1bWVudHMubGVuZ3RoOyBpKyspIHtcbiAgICB2YXIgc291cmNlID0gYXJndW1lbnRzW2ldICE9IG51bGwgPyBhcmd1bWVudHNbaV0gOiB7fTtcblxuICAgIGlmIChpICUgMikge1xuICAgICAgb3duS2V5cyhPYmplY3Qoc291cmNlKSwgdHJ1ZSkuZm9yRWFjaChmdW5jdGlvbiAoa2V5KSB7XG4gICAgICAgIF9kZWZpbmVQcm9wZXJ0eSh0YXJnZXQsIGtleSwgc291cmNlW2tleV0pO1xuICAgICAgfSk7XG4gICAgfSBlbHNlIGlmIChPYmplY3QuZ2V0T3duUHJvcGVydHlEZXNjcmlwdG9ycykge1xuICAgICAgT2JqZWN0LmRlZmluZVByb3BlcnRpZXModGFyZ2V0LCBPYmplY3QuZ2V0T3duUHJvcGVydHlEZXNjcmlwdG9ycyhzb3VyY2UpKTtcbiAgICB9IGVsc2Uge1xuICAgICAgb3duS2V5cyhPYmplY3Qoc291cmNlKSkuZm9yRWFjaChmdW5jdGlvbiAoa2V5KSB7XG4gICAgICAgIE9iamVjdC5kZWZpbmVQcm9wZXJ0eSh0YXJnZXQsIGtleSwgT2JqZWN0LmdldE93blByb3BlcnR5RGVzY3JpcHRvcihzb3VyY2UsIGtleSkpO1xuICAgICAgfSk7XG4gICAgfVxuICB9XG5cbiAgcmV0dXJuIHRhcmdldDtcbn1cblxuZnVuY3Rpb24gY29tcG9zZSgpIHtcbiAgZm9yICh2YXIgX2xlbiA9IGFyZ3VtZW50cy5sZW5ndGgsIGZucyA9IG5ldyBBcnJheShfbGVuKSwgX2tleSA9IDA7IF9rZXkgPCBfbGVuOyBfa2V5KyspIHtcbiAgICBmbnNbX2tleV0gPSBhcmd1bWVudHNbX2tleV07XG4gIH1cblxuICByZXR1cm4gZnVuY3Rpb24gKHgpIHtcbiAgICByZXR1cm4gZm5zLnJlZHVjZVJpZ2h0KGZ1bmN0aW9uICh5LCBmKSB7XG4gICAgICByZXR1cm4gZih5KTtcbiAgICB9LCB4KTtcbiAgfTtcbn1cblxuZnVuY3Rpb24gY3VycnkoZm4pIHtcbiAgcmV0dXJuIGZ1bmN0aW9uIGN1cnJpZWQoKSB7XG4gICAgdmFyIF90aGlzID0gdGhpcztcblxuICAgIGZvciAodmFyIF9sZW4yID0gYXJndW1lbnRzLmxlbmd0aCwgYXJncyA9IG5ldyBBcnJheShfbGVuMiksIF9rZXkyID0gMDsgX2tleTIgPCBfbGVuMjsgX2tleTIrKykge1xuICAgICAgYXJnc1tfa2V5Ml0gPSBhcmd1bWVudHNbX2tleTJdO1xuICAgIH1cblxuICAgIHJldHVybiBhcmdzLmxlbmd0aCA+PSBmbi5sZW5ndGggPyBmbi5hcHBseSh0aGlzLCBhcmdzKSA6IGZ1bmN0aW9uICgpIHtcbiAgICAgIGZvciAodmFyIF9sZW4zID0gYXJndW1lbnRzLmxlbmd0aCwgbmV4dEFyZ3MgPSBuZXcgQXJyYXkoX2xlbjMpLCBfa2V5MyA9IDA7IF9rZXkzIDwgX2xlbjM7IF9rZXkzKyspIHtcbiAgICAgICAgbmV4dEFyZ3NbX2tleTNdID0gYXJndW1lbnRzW19rZXkzXTtcbiAgICAgIH1cblxuICAgICAgcmV0dXJuIGN1cnJpZWQuYXBwbHkoX3RoaXMsIFtdLmNvbmNhdChhcmdzLCBuZXh0QXJncykpO1xuICAgIH07XG4gIH07XG59XG5cbmZ1bmN0aW9uIGlzT2JqZWN0KHZhbHVlKSB7XG4gIHJldHVybiB7fS50b1N0cmluZy5jYWxsKHZhbHVlKS5pbmNsdWRlcygnT2JqZWN0Jyk7XG59XG5cbmZ1bmN0aW9uIGlzRW1wdHkob2JqKSB7XG4gIHJldHVybiAhT2JqZWN0LmtleXMob2JqKS5sZW5ndGg7XG59XG5cbmZ1bmN0aW9uIGlzRnVuY3Rpb24odmFsdWUpIHtcbiAgcmV0dXJuIHR5cGVvZiB2YWx1ZSA9PT0gJ2Z1bmN0aW9uJztcbn1cblxuZnVuY3Rpb24gaGFzT3duUHJvcGVydHkob2JqZWN0LCBwcm9wZXJ0eSkge1xuICByZXR1cm4gT2JqZWN0LnByb3RvdHlwZS5oYXNPd25Qcm9wZXJ0eS5jYWxsKG9iamVjdCwgcHJvcGVydHkpO1xufVxuXG5mdW5jdGlvbiB2YWxpZGF0ZUNoYW5nZXMoaW5pdGlhbCwgY2hhbmdlcykge1xuICBpZiAoIWlzT2JqZWN0KGNoYW5nZXMpKSBlcnJvckhhbmRsZXIoJ2NoYW5nZVR5cGUnKTtcbiAgaWYgKE9iamVjdC5rZXlzKGNoYW5nZXMpLnNvbWUoZnVuY3Rpb24gKGZpZWxkKSB7XG4gICAgcmV0dXJuICFoYXNPd25Qcm9wZXJ0eShpbml0aWFsLCBmaWVsZCk7XG4gIH0pKSBlcnJvckhhbmRsZXIoJ2NoYW5nZUZpZWxkJyk7XG4gIHJldHVybiBjaGFuZ2VzO1xufVxuXG5mdW5jdGlvbiB2YWxpZGF0ZVNlbGVjdG9yKHNlbGVjdG9yKSB7XG4gIGlmICghaXNGdW5jdGlvbihzZWxlY3RvcikpIGVycm9ySGFuZGxlcignc2VsZWN0b3JUeXBlJyk7XG59XG5cbmZ1bmN0aW9uIHZhbGlkYXRlSGFuZGxlcihoYW5kbGVyKSB7XG4gIGlmICghKGlzRnVuY3Rpb24oaGFuZGxlcikgfHwgaXNPYmplY3QoaGFuZGxlcikpKSBlcnJvckhhbmRsZXIoJ2hhbmRsZXJUeXBlJyk7XG4gIGlmIChpc09iamVjdChoYW5kbGVyKSAmJiBPYmplY3QudmFsdWVzKGhhbmRsZXIpLnNvbWUoZnVuY3Rpb24gKF9oYW5kbGVyKSB7XG4gICAgcmV0dXJuICFpc0Z1bmN0aW9uKF9oYW5kbGVyKTtcbiAgfSkpIGVycm9ySGFuZGxlcignaGFuZGxlcnNUeXBlJyk7XG59XG5cbmZ1bmN0aW9uIHZhbGlkYXRlSW5pdGlhbChpbml0aWFsKSB7XG4gIGlmICghaW5pdGlhbCkgZXJyb3JIYW5kbGVyKCdpbml0aWFsSXNSZXF1aXJlZCcpO1xuICBpZiAoIWlzT2JqZWN0KGluaXRpYWwpKSBlcnJvckhhbmRsZXIoJ2luaXRpYWxUeXBlJyk7XG4gIGlmIChpc0VtcHR5KGluaXRpYWwpKSBlcnJvckhhbmRsZXIoJ2luaXRpYWxDb250ZW50Jyk7XG59XG5cbmZ1bmN0aW9uIHRocm93RXJyb3IoZXJyb3JNZXNzYWdlcywgdHlwZSkge1xuICB0aHJvdyBuZXcgRXJyb3IoZXJyb3JNZXNzYWdlc1t0eXBlXSB8fCBlcnJvck1lc3NhZ2VzW1wiZGVmYXVsdFwiXSk7XG59XG5cbnZhciBlcnJvck1lc3NhZ2VzID0ge1xuICBpbml0aWFsSXNSZXF1aXJlZDogJ2luaXRpYWwgc3RhdGUgaXMgcmVxdWlyZWQnLFxuICBpbml0aWFsVHlwZTogJ2luaXRpYWwgc3RhdGUgc2hvdWxkIGJlIGFuIG9iamVjdCcsXG4gIGluaXRpYWxDb250ZW50OiAnaW5pdGlhbCBzdGF0ZSBzaG91bGRuXFwndCBiZSBhbiBlbXB0eSBvYmplY3QnLFxuICBoYW5kbGVyVHlwZTogJ2hhbmRsZXIgc2hvdWxkIGJlIGFuIG9iamVjdCBvciBhIGZ1bmN0aW9uJyxcbiAgaGFuZGxlcnNUeXBlOiAnYWxsIGhhbmRsZXJzIHNob3VsZCBiZSBhIGZ1bmN0aW9ucycsXG4gIHNlbGVjdG9yVHlwZTogJ3NlbGVjdG9yIHNob3VsZCBiZSBhIGZ1bmN0aW9uJyxcbiAgY2hhbmdlVHlwZTogJ3Byb3ZpZGVkIHZhbHVlIG9mIGNoYW5nZXMgc2hvdWxkIGJlIGFuIG9iamVjdCcsXG4gIGNoYW5nZUZpZWxkOiAnaXQgc2VhbXMgeW91IHdhbnQgdG8gY2hhbmdlIGEgZmllbGQgaW4gdGhlIHN0YXRlIHdoaWNoIGlzIG5vdCBzcGVjaWZpZWQgaW4gdGhlIFwiaW5pdGlhbFwiIHN0YXRlJyxcbiAgXCJkZWZhdWx0XCI6ICdhbiB1bmtub3duIGVycm9yIGFjY3VyZWQgaW4gYHN0YXRlLWxvY2FsYCBwYWNrYWdlJ1xufTtcbnZhciBlcnJvckhhbmRsZXIgPSBjdXJyeSh0aHJvd0Vycm9yKShlcnJvck1lc3NhZ2VzKTtcbnZhciB2YWxpZGF0b3JzID0ge1xuICBjaGFuZ2VzOiB2YWxpZGF0ZUNoYW5nZXMsXG4gIHNlbGVjdG9yOiB2YWxpZGF0ZVNlbGVjdG9yLFxuICBoYW5kbGVyOiB2YWxpZGF0ZUhhbmRsZXIsXG4gIGluaXRpYWw6IHZhbGlkYXRlSW5pdGlhbFxufTtcblxuZnVuY3Rpb24gY3JlYXRlKGluaXRpYWwpIHtcbiAgdmFyIGhhbmRsZXIgPSBhcmd1bWVudHMubGVuZ3RoID4gMSAmJiBhcmd1bWVudHNbMV0gIT09IHVuZGVmaW5lZCA/IGFyZ3VtZW50c1sxXSA6IHt9O1xuICB2YWxpZGF0b3JzLmluaXRpYWwoaW5pdGlhbCk7XG4gIHZhbGlkYXRvcnMuaGFuZGxlcihoYW5kbGVyKTtcbiAgdmFyIHN0YXRlID0ge1xuICAgIGN1cnJlbnQ6IGluaXRpYWxcbiAgfTtcbiAgdmFyIGRpZFVwZGF0ZSA9IGN1cnJ5KGRpZFN0YXRlVXBkYXRlKShzdGF0ZSwgaGFuZGxlcik7XG4gIHZhciB1cGRhdGUgPSBjdXJyeSh1cGRhdGVTdGF0ZSkoc3RhdGUpO1xuICB2YXIgdmFsaWRhdGUgPSBjdXJyeSh2YWxpZGF0b3JzLmNoYW5nZXMpKGluaXRpYWwpO1xuICB2YXIgZ2V0Q2hhbmdlcyA9IGN1cnJ5KGV4dHJhY3RDaGFuZ2VzKShzdGF0ZSk7XG5cbiAgZnVuY3Rpb24gZ2V0U3RhdGUoKSB7XG4gICAgdmFyIHNlbGVjdG9yID0gYXJndW1lbnRzLmxlbmd0aCA+IDAgJiYgYXJndW1lbnRzWzBdICE9PSB1bmRlZmluZWQgPyBhcmd1bWVudHNbMF0gOiBmdW5jdGlvbiAoc3RhdGUpIHtcbiAgICAgIHJldHVybiBzdGF0ZTtcbiAgICB9O1xuICAgIHZhbGlkYXRvcnMuc2VsZWN0b3Ioc2VsZWN0b3IpO1xuICAgIHJldHVybiBzZWxlY3RvcihzdGF0ZS5jdXJyZW50KTtcbiAgfVxuXG4gIGZ1bmN0aW9uIHNldFN0YXRlKGNhdXNlZENoYW5nZXMpIHtcbiAgICBjb21wb3NlKGRpZFVwZGF0ZSwgdXBkYXRlLCB2YWxpZGF0ZSwgZ2V0Q2hhbmdlcykoY2F1c2VkQ2hhbmdlcyk7XG4gIH1cblxuICByZXR1cm4gW2dldFN0YXRlLCBzZXRTdGF0ZV07XG59XG5cbmZ1bmN0aW9uIGV4dHJhY3RDaGFuZ2VzKHN0YXRlLCBjYXVzZWRDaGFuZ2VzKSB7XG4gIHJldHVybiBpc0Z1bmN0aW9uKGNhdXNlZENoYW5nZXMpID8gY2F1c2VkQ2hhbmdlcyhzdGF0ZS5jdXJyZW50KSA6IGNhdXNlZENoYW5nZXM7XG59XG5cbmZ1bmN0aW9uIHVwZGF0ZVN0YXRlKHN0YXRlLCBjaGFuZ2VzKSB7XG4gIHN0YXRlLmN1cnJlbnQgPSBfb2JqZWN0U3ByZWFkMihfb2JqZWN0U3ByZWFkMih7fSwgc3RhdGUuY3VycmVudCksIGNoYW5nZXMpO1xuICByZXR1cm4gY2hhbmdlcztcbn1cblxuZnVuY3Rpb24gZGlkU3RhdGVVcGRhdGUoc3RhdGUsIGhhbmRsZXIsIGNoYW5nZXMpIHtcbiAgaXNGdW5jdGlvbihoYW5kbGVyKSA/IGhhbmRsZXIoc3RhdGUuY3VycmVudCkgOiBPYmplY3Qua2V5cyhjaGFuZ2VzKS5mb3JFYWNoKGZ1bmN0aW9uIChmaWVsZCkge1xuICAgIHZhciBfaGFuZGxlciRmaWVsZDtcblxuICAgIHJldHVybiAoX2hhbmRsZXIkZmllbGQgPSBoYW5kbGVyW2ZpZWxkXSkgPT09IG51bGwgfHwgX2hhbmRsZXIkZmllbGQgPT09IHZvaWQgMCA/IHZvaWQgMCA6IF9oYW5kbGVyJGZpZWxkLmNhbGwoaGFuZGxlciwgc3RhdGUuY3VycmVudFtmaWVsZF0pO1xuICB9KTtcbiAgcmV0dXJuIGNoYW5nZXM7XG59XG5cbnZhciBpbmRleCA9IHtcbiAgY3JlYXRlOiBjcmVhdGVcbn07XG5cbmV4cG9ydCBkZWZhdWx0IGluZGV4O1xuIiwgInZhciBjb25maWcgPSB7XG4gIHBhdGhzOiB7XG4gICAgdnM6ICdodHRwczovL2Nkbi5qc2RlbGl2ci5uZXQvbnBtL21vbmFjby1lZGl0b3JAMC4zNi4xL21pbi92cydcbiAgfVxufTtcblxuZXhwb3J0IGRlZmF1bHQgY29uZmlnO1xuIiwgImZ1bmN0aW9uIGN1cnJ5KGZuKSB7XG4gIHJldHVybiBmdW5jdGlvbiBjdXJyaWVkKCkge1xuICAgIHZhciBfdGhpcyA9IHRoaXM7XG5cbiAgICBmb3IgKHZhciBfbGVuID0gYXJndW1lbnRzLmxlbmd0aCwgYXJncyA9IG5ldyBBcnJheShfbGVuKSwgX2tleSA9IDA7IF9rZXkgPCBfbGVuOyBfa2V5KyspIHtcbiAgICAgIGFyZ3NbX2tleV0gPSBhcmd1bWVudHNbX2tleV07XG4gICAgfVxuXG4gICAgcmV0dXJuIGFyZ3MubGVuZ3RoID49IGZuLmxlbmd0aCA/IGZuLmFwcGx5KHRoaXMsIGFyZ3MpIDogZnVuY3Rpb24gKCkge1xuICAgICAgZm9yICh2YXIgX2xlbjIgPSBhcmd1bWVudHMubGVuZ3RoLCBuZXh0QXJncyA9IG5ldyBBcnJheShfbGVuMiksIF9rZXkyID0gMDsgX2tleTIgPCBfbGVuMjsgX2tleTIrKykge1xuICAgICAgICBuZXh0QXJnc1tfa2V5Ml0gPSBhcmd1bWVudHNbX2tleTJdO1xuICAgICAgfVxuXG4gICAgICByZXR1cm4gY3VycmllZC5hcHBseShfdGhpcywgW10uY29uY2F0KGFyZ3MsIG5leHRBcmdzKSk7XG4gICAgfTtcbiAgfTtcbn1cblxuZXhwb3J0IGRlZmF1bHQgY3Vycnk7XG4iLCAiZnVuY3Rpb24gaXNPYmplY3QodmFsdWUpIHtcbiAgcmV0dXJuIHt9LnRvU3RyaW5nLmNhbGwodmFsdWUpLmluY2x1ZGVzKCdPYmplY3QnKTtcbn1cblxuZXhwb3J0IGRlZmF1bHQgaXNPYmplY3Q7XG4iLCAiaW1wb3J0IGN1cnJ5IGZyb20gJy4uL3V0aWxzL2N1cnJ5LmpzJztcbmltcG9ydCBpc09iamVjdCBmcm9tICcuLi91dGlscy9pc09iamVjdC5qcyc7XG5cbi8qKlxuICogdmFsaWRhdGVzIHRoZSBjb25maWd1cmF0aW9uIG9iamVjdCBhbmQgaW5mb3JtcyBhYm91dCBkZXByZWNhdGlvblxuICogQHBhcmFtIHtPYmplY3R9IGNvbmZpZyAtIHRoZSBjb25maWd1cmF0aW9uIG9iamVjdCBcbiAqIEByZXR1cm4ge09iamVjdH0gY29uZmlnIC0gdGhlIHZhbGlkYXRlZCBjb25maWd1cmF0aW9uIG9iamVjdFxuICovXG5cbmZ1bmN0aW9uIHZhbGlkYXRlQ29uZmlnKGNvbmZpZykge1xuICBpZiAoIWNvbmZpZykgZXJyb3JIYW5kbGVyKCdjb25maWdJc1JlcXVpcmVkJyk7XG4gIGlmICghaXNPYmplY3QoY29uZmlnKSkgZXJyb3JIYW5kbGVyKCdjb25maWdUeXBlJyk7XG5cbiAgaWYgKGNvbmZpZy51cmxzKSB7XG4gICAgaW5mb3JtQWJvdXREZXByZWNhdGlvbigpO1xuICAgIHJldHVybiB7XG4gICAgICBwYXRoczoge1xuICAgICAgICB2czogY29uZmlnLnVybHMubW9uYWNvQmFzZVxuICAgICAgfVxuICAgIH07XG4gIH1cblxuICByZXR1cm4gY29uZmlnO1xufVxuLyoqXG4gKiBsb2dzIGRlcHJlY2F0aW9uIG1lc3NhZ2VcbiAqL1xuXG5cbmZ1bmN0aW9uIGluZm9ybUFib3V0RGVwcmVjYXRpb24oKSB7XG4gIGNvbnNvbGUud2FybihlcnJvck1lc3NhZ2VzLmRlcHJlY2F0aW9uKTtcbn1cblxuZnVuY3Rpb24gdGhyb3dFcnJvcihlcnJvck1lc3NhZ2VzLCB0eXBlKSB7XG4gIHRocm93IG5ldyBFcnJvcihlcnJvck1lc3NhZ2VzW3R5cGVdIHx8IGVycm9yTWVzc2FnZXNbXCJkZWZhdWx0XCJdKTtcbn1cblxudmFyIGVycm9yTWVzc2FnZXMgPSB7XG4gIGNvbmZpZ0lzUmVxdWlyZWQ6ICd0aGUgY29uZmlndXJhdGlvbiBvYmplY3QgaXMgcmVxdWlyZWQnLFxuICBjb25maWdUeXBlOiAndGhlIGNvbmZpZ3VyYXRpb24gb2JqZWN0IHNob3VsZCBiZSBhbiBvYmplY3QnLFxuICBcImRlZmF1bHRcIjogJ2FuIHVua25vd24gZXJyb3IgYWNjdXJlZCBpbiBgQG1vbmFjby1lZGl0b3IvbG9hZGVyYCBwYWNrYWdlJyxcbiAgZGVwcmVjYXRpb246IFwiRGVwcmVjYXRpb24gd2FybmluZyFcXG4gICAgWW91IGFyZSB1c2luZyBkZXByZWNhdGVkIHdheSBvZiBjb25maWd1cmF0aW9uLlxcblxcbiAgICBJbnN0ZWFkIG9mIHVzaW5nXFxuICAgICAgbW9uYWNvLmNvbmZpZyh7IHVybHM6IHsgbW9uYWNvQmFzZTogJy4uLicgfSB9KVxcbiAgICB1c2VcXG4gICAgICBtb25hY28uY29uZmlnKHsgcGF0aHM6IHsgdnM6ICcuLi4nIH0gfSlcXG5cXG4gICAgRm9yIG1vcmUgcGxlYXNlIGNoZWNrIHRoZSBsaW5rIGh0dHBzOi8vZ2l0aHViLmNvbS9zdXJlbi1hdG95YW4vbW9uYWNvLWxvYWRlciNjb25maWdcXG4gIFwiXG59O1xudmFyIGVycm9ySGFuZGxlciA9IGN1cnJ5KHRocm93RXJyb3IpKGVycm9yTWVzc2FnZXMpO1xudmFyIHZhbGlkYXRvcnMgPSB7XG4gIGNvbmZpZzogdmFsaWRhdGVDb25maWdcbn07XG5cbmV4cG9ydCBkZWZhdWx0IHZhbGlkYXRvcnM7XG5leHBvcnQgeyBlcnJvckhhbmRsZXIsIGVycm9yTWVzc2FnZXMgfTtcbiIsICJ2YXIgY29tcG9zZSA9IGZ1bmN0aW9uIGNvbXBvc2UoKSB7XG4gIGZvciAodmFyIF9sZW4gPSBhcmd1bWVudHMubGVuZ3RoLCBmbnMgPSBuZXcgQXJyYXkoX2xlbiksIF9rZXkgPSAwOyBfa2V5IDwgX2xlbjsgX2tleSsrKSB7XG4gICAgZm5zW19rZXldID0gYXJndW1lbnRzW19rZXldO1xuICB9XG5cbiAgcmV0dXJuIGZ1bmN0aW9uICh4KSB7XG4gICAgcmV0dXJuIGZucy5yZWR1Y2VSaWdodChmdW5jdGlvbiAoeSwgZikge1xuICAgICAgcmV0dXJuIGYoeSk7XG4gICAgfSwgeCk7XG4gIH07XG59O1xuXG5leHBvcnQgZGVmYXVsdCBjb21wb3NlO1xuIiwgImltcG9ydCB7IG9iamVjdFNwcmVhZDIgYXMgX29iamVjdFNwcmVhZDIgfSBmcm9tICcuLi9fdmlydHVhbC9fcm9sbHVwUGx1Z2luQmFiZWxIZWxwZXJzLmpzJztcblxuZnVuY3Rpb24gbWVyZ2UodGFyZ2V0LCBzb3VyY2UpIHtcbiAgT2JqZWN0LmtleXMoc291cmNlKS5mb3JFYWNoKGZ1bmN0aW9uIChrZXkpIHtcbiAgICBpZiAoc291cmNlW2tleV0gaW5zdGFuY2VvZiBPYmplY3QpIHtcbiAgICAgIGlmICh0YXJnZXRba2V5XSkge1xuICAgICAgICBPYmplY3QuYXNzaWduKHNvdXJjZVtrZXldLCBtZXJnZSh0YXJnZXRba2V5XSwgc291cmNlW2tleV0pKTtcbiAgICAgIH1cbiAgICB9XG4gIH0pO1xuICByZXR1cm4gX29iamVjdFNwcmVhZDIoX29iamVjdFNwcmVhZDIoe30sIHRhcmdldCksIHNvdXJjZSk7XG59XG5cbmV4cG9ydCBkZWZhdWx0IG1lcmdlO1xuIiwgIi8vIFRoZSBzb3VyY2UgKGhhcyBiZWVuIGNoYW5nZWQpIGlzIGh0dHBzOi8vZ2l0aHViLmNvbS9mYWNlYm9vay9yZWFjdC9pc3N1ZXMvNTQ2NSNpc3N1ZWNvbW1lbnQtMTU3ODg4MzI1XG52YXIgQ0FOQ0VMQVRJT05fTUVTU0FHRSA9IHtcbiAgdHlwZTogJ2NhbmNlbGF0aW9uJyxcbiAgbXNnOiAnb3BlcmF0aW9uIGlzIG1hbnVhbGx5IGNhbmNlbGVkJ1xufTtcblxuZnVuY3Rpb24gbWFrZUNhbmNlbGFibGUocHJvbWlzZSkge1xuICB2YXIgaGFzQ2FuY2VsZWRfID0gZmFsc2U7XG4gIHZhciB3cmFwcGVkUHJvbWlzZSA9IG5ldyBQcm9taXNlKGZ1bmN0aW9uIChyZXNvbHZlLCByZWplY3QpIHtcbiAgICBwcm9taXNlLnRoZW4oZnVuY3Rpb24gKHZhbCkge1xuICAgICAgcmV0dXJuIGhhc0NhbmNlbGVkXyA/IHJlamVjdChDQU5DRUxBVElPTl9NRVNTQUdFKSA6IHJlc29sdmUodmFsKTtcbiAgICB9KTtcbiAgICBwcm9taXNlW1wiY2F0Y2hcIl0ocmVqZWN0KTtcbiAgfSk7XG4gIHJldHVybiB3cmFwcGVkUHJvbWlzZS5jYW5jZWwgPSBmdW5jdGlvbiAoKSB7XG4gICAgcmV0dXJuIGhhc0NhbmNlbGVkXyA9IHRydWU7XG4gIH0sIHdyYXBwZWRQcm9taXNlO1xufVxuXG5leHBvcnQgZGVmYXVsdCBtYWtlQ2FuY2VsYWJsZTtcbmV4cG9ydCB7IENBTkNFTEFUSU9OX01FU1NBR0UgfTtcbiIsICJpbXBvcnQgeyBzbGljZWRUb0FycmF5IGFzIF9zbGljZWRUb0FycmF5LCBvYmplY3RXaXRob3V0UHJvcGVydGllcyBhcyBfb2JqZWN0V2l0aG91dFByb3BlcnRpZXMgfSBmcm9tICcuLi9fdmlydHVhbC9fcm9sbHVwUGx1Z2luQmFiZWxIZWxwZXJzLmpzJztcbmltcG9ydCBzdGF0ZSBmcm9tICdzdGF0ZS1sb2NhbCc7XG5pbXBvcnQgY29uZmlnJDEgZnJvbSAnLi4vY29uZmlnL2luZGV4LmpzJztcbmltcG9ydCB2YWxpZGF0b3JzIGZyb20gJy4uL3ZhbGlkYXRvcnMvaW5kZXguanMnO1xuaW1wb3J0IGNvbXBvc2UgZnJvbSAnLi4vdXRpbHMvY29tcG9zZS5qcyc7XG5pbXBvcnQgbWVyZ2UgZnJvbSAnLi4vdXRpbHMvZGVlcE1lcmdlLmpzJztcbmltcG9ydCBtYWtlQ2FuY2VsYWJsZSBmcm9tICcuLi91dGlscy9tYWtlQ2FuY2VsYWJsZS5qcyc7XG5cbi8qKiB0aGUgbG9jYWwgc3RhdGUgb2YgdGhlIG1vZHVsZSAqL1xuXG52YXIgX3N0YXRlJGNyZWF0ZSA9IHN0YXRlLmNyZWF0ZSh7XG4gIGNvbmZpZzogY29uZmlnJDEsXG4gIGlzSW5pdGlhbGl6ZWQ6IGZhbHNlLFxuICByZXNvbHZlOiBudWxsLFxuICByZWplY3Q6IG51bGwsXG4gIG1vbmFjbzogbnVsbFxufSksXG4gICAgX3N0YXRlJGNyZWF0ZTIgPSBfc2xpY2VkVG9BcnJheShfc3RhdGUkY3JlYXRlLCAyKSxcbiAgICBnZXRTdGF0ZSA9IF9zdGF0ZSRjcmVhdGUyWzBdLFxuICAgIHNldFN0YXRlID0gX3N0YXRlJGNyZWF0ZTJbMV07XG4vKipcbiAqIHNldCB0aGUgbG9hZGVyIGNvbmZpZ3VyYXRpb25cbiAqIEBwYXJhbSB7T2JqZWN0fSBjb25maWcgLSB0aGUgY29uZmlndXJhdGlvbiBvYmplY3RcbiAqL1xuXG5cbmZ1bmN0aW9uIGNvbmZpZyhnbG9iYWxDb25maWcpIHtcbiAgdmFyIF92YWxpZGF0b3JzJGNvbmZpZyA9IHZhbGlkYXRvcnMuY29uZmlnKGdsb2JhbENvbmZpZyksXG4gICAgICBtb25hY28gPSBfdmFsaWRhdG9ycyRjb25maWcubW9uYWNvLFxuICAgICAgY29uZmlnID0gX29iamVjdFdpdGhvdXRQcm9wZXJ0aWVzKF92YWxpZGF0b3JzJGNvbmZpZywgW1wibW9uYWNvXCJdKTtcblxuICBzZXRTdGF0ZShmdW5jdGlvbiAoc3RhdGUpIHtcbiAgICByZXR1cm4ge1xuICAgICAgY29uZmlnOiBtZXJnZShzdGF0ZS5jb25maWcsIGNvbmZpZyksXG4gICAgICBtb25hY286IG1vbmFjb1xuICAgIH07XG4gIH0pO1xufVxuLyoqXG4gKiBoYW5kbGVzIHRoZSBpbml0aWFsaXphdGlvbiBvZiB0aGUgbW9uYWNvLWVkaXRvclxuICogQHJldHVybiB7UHJvbWlzZX0gLSByZXR1cm5zIGFuIGluc3RhbmNlIG9mIG1vbmFjbyAod2l0aCBhIGNhbmNlbGFibGUgcHJvbWlzZSlcbiAqL1xuXG5cbmZ1bmN0aW9uIGluaXQoKSB7XG4gIHZhciBzdGF0ZSA9IGdldFN0YXRlKGZ1bmN0aW9uIChfcmVmKSB7XG4gICAgdmFyIG1vbmFjbyA9IF9yZWYubW9uYWNvLFxuICAgICAgICBpc0luaXRpYWxpemVkID0gX3JlZi5pc0luaXRpYWxpemVkLFxuICAgICAgICByZXNvbHZlID0gX3JlZi5yZXNvbHZlO1xuICAgIHJldHVybiB7XG4gICAgICBtb25hY286IG1vbmFjbyxcbiAgICAgIGlzSW5pdGlhbGl6ZWQ6IGlzSW5pdGlhbGl6ZWQsXG4gICAgICByZXNvbHZlOiByZXNvbHZlXG4gICAgfTtcbiAgfSk7XG5cbiAgaWYgKCFzdGF0ZS5pc0luaXRpYWxpemVkKSB7XG4gICAgc2V0U3RhdGUoe1xuICAgICAgaXNJbml0aWFsaXplZDogdHJ1ZVxuICAgIH0pO1xuXG4gICAgaWYgKHN0YXRlLm1vbmFjbykge1xuICAgICAgc3RhdGUucmVzb2x2ZShzdGF0ZS5tb25hY28pO1xuICAgICAgcmV0dXJuIG1ha2VDYW5jZWxhYmxlKHdyYXBwZXJQcm9taXNlKTtcbiAgICB9XG5cbiAgICBpZiAod2luZG93Lm1vbmFjbyAmJiB3aW5kb3cubW9uYWNvLmVkaXRvcikge1xuICAgICAgc3RvcmVNb25hY29JbnN0YW5jZSh3aW5kb3cubW9uYWNvKTtcbiAgICAgIHN0YXRlLnJlc29sdmUod2luZG93Lm1vbmFjbyk7XG4gICAgICByZXR1cm4gbWFrZUNhbmNlbGFibGUod3JhcHBlclByb21pc2UpO1xuICAgIH1cblxuICAgIGNvbXBvc2UoaW5qZWN0U2NyaXB0cywgZ2V0TW9uYWNvTG9hZGVyU2NyaXB0KShjb25maWd1cmVMb2FkZXIpO1xuICB9XG5cbiAgcmV0dXJuIG1ha2VDYW5jZWxhYmxlKHdyYXBwZXJQcm9taXNlKTtcbn1cbi8qKlxuICogaW5qZWN0cyBwcm92aWRlZCBzY3JpcHRzIGludG8gdGhlIGRvY3VtZW50LmJvZHlcbiAqIEBwYXJhbSB7T2JqZWN0fSBzY3JpcHQgLSBhbiBIVE1MIHNjcmlwdCBlbGVtZW50XG4gKiBAcmV0dXJuIHtPYmplY3R9IC0gdGhlIGluamVjdGVkIEhUTUwgc2NyaXB0IGVsZW1lbnRcbiAqL1xuXG5cbmZ1bmN0aW9uIGluamVjdFNjcmlwdHMoc2NyaXB0KSB7XG4gIHJldHVybiBkb2N1bWVudC5ib2R5LmFwcGVuZENoaWxkKHNjcmlwdCk7XG59XG4vKipcbiAqIGNyZWF0ZXMgYW4gSFRNTCBzY3JpcHQgZWxlbWVudCB3aXRoL3dpdGhvdXQgcHJvdmlkZWQgc3JjXG4gKiBAcGFyYW0ge3N0cmluZ30gW3NyY10gLSB0aGUgc291cmNlIHBhdGggb2YgdGhlIHNjcmlwdFxuICogQHJldHVybiB7T2JqZWN0fSAtIHRoZSBjcmVhdGVkIEhUTUwgc2NyaXB0IGVsZW1lbnRcbiAqL1xuXG5cbmZ1bmN0aW9uIGNyZWF0ZVNjcmlwdChzcmMpIHtcbiAgdmFyIHNjcmlwdCA9IGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ3NjcmlwdCcpO1xuICByZXR1cm4gc3JjICYmIChzY3JpcHQuc3JjID0gc3JjKSwgc2NyaXB0O1xufVxuLyoqXG4gKiBjcmVhdGVzIGFuIEhUTUwgc2NyaXB0IGVsZW1lbnQgd2l0aCB0aGUgbW9uYWNvIGxvYWRlciBzcmNcbiAqIEByZXR1cm4ge09iamVjdH0gLSB0aGUgY3JlYXRlZCBIVE1MIHNjcmlwdCBlbGVtZW50XG4gKi9cblxuXG5mdW5jdGlvbiBnZXRNb25hY29Mb2FkZXJTY3JpcHQoY29uZmlndXJlTG9hZGVyKSB7XG4gIHZhciBzdGF0ZSA9IGdldFN0YXRlKGZ1bmN0aW9uIChfcmVmMikge1xuICAgIHZhciBjb25maWcgPSBfcmVmMi5jb25maWcsXG4gICAgICAgIHJlamVjdCA9IF9yZWYyLnJlamVjdDtcbiAgICByZXR1cm4ge1xuICAgICAgY29uZmlnOiBjb25maWcsXG4gICAgICByZWplY3Q6IHJlamVjdFxuICAgIH07XG4gIH0pO1xuICB2YXIgbG9hZGVyU2NyaXB0ID0gY3JlYXRlU2NyaXB0KFwiXCIuY29uY2F0KHN0YXRlLmNvbmZpZy5wYXRocy52cywgXCIvbG9hZGVyLmpzXCIpKTtcblxuICBsb2FkZXJTY3JpcHQub25sb2FkID0gZnVuY3Rpb24gKCkge1xuICAgIHJldHVybiBjb25maWd1cmVMb2FkZXIoKTtcbiAgfTtcblxuICBsb2FkZXJTY3JpcHQub25lcnJvciA9IHN0YXRlLnJlamVjdDtcbiAgcmV0dXJuIGxvYWRlclNjcmlwdDtcbn1cbi8qKlxuICogY29uZmlndXJlcyB0aGUgbW9uYWNvIGxvYWRlclxuICovXG5cblxuZnVuY3Rpb24gY29uZmlndXJlTG9hZGVyKCkge1xuICB2YXIgc3RhdGUgPSBnZXRTdGF0ZShmdW5jdGlvbiAoX3JlZjMpIHtcbiAgICB2YXIgY29uZmlnID0gX3JlZjMuY29uZmlnLFxuICAgICAgICByZXNvbHZlID0gX3JlZjMucmVzb2x2ZSxcbiAgICAgICAgcmVqZWN0ID0gX3JlZjMucmVqZWN0O1xuICAgIHJldHVybiB7XG4gICAgICBjb25maWc6IGNvbmZpZyxcbiAgICAgIHJlc29sdmU6IHJlc29sdmUsXG4gICAgICByZWplY3Q6IHJlamVjdFxuICAgIH07XG4gIH0pO1xuICB2YXIgcmVxdWlyZSA9IHdpbmRvdy5yZXF1aXJlO1xuXG4gIHJlcXVpcmUuY29uZmlnKHN0YXRlLmNvbmZpZyk7XG5cbiAgcmVxdWlyZShbJ3ZzL2VkaXRvci9lZGl0b3IubWFpbiddLCBmdW5jdGlvbiAobW9uYWNvKSB7XG4gICAgc3RvcmVNb25hY29JbnN0YW5jZShtb25hY28pO1xuICAgIHN0YXRlLnJlc29sdmUobW9uYWNvKTtcbiAgfSwgZnVuY3Rpb24gKGVycm9yKSB7XG4gICAgc3RhdGUucmVqZWN0KGVycm9yKTtcbiAgfSk7XG59XG4vKipcbiAqIHN0b3JlIG1vbmFjbyBpbnN0YW5jZSBpbiBsb2NhbCBzdGF0ZVxuICovXG5cblxuZnVuY3Rpb24gc3RvcmVNb25hY29JbnN0YW5jZShtb25hY28pIHtcbiAgaWYgKCFnZXRTdGF0ZSgpLm1vbmFjbykge1xuICAgIHNldFN0YXRlKHtcbiAgICAgIG1vbmFjbzogbW9uYWNvXG4gICAgfSk7XG4gIH1cbn1cbi8qKlxuICogaW50ZXJuYWwgaGVscGVyIGZ1bmN0aW9uXG4gKiBleHRyYWN0cyBzdG9yZWQgbW9uYWNvIGluc3RhbmNlXG4gKiBAcmV0dXJuIHtPYmplY3R8bnVsbH0gLSB0aGUgbW9uYWNvIGluc3RhbmNlXG4gKi9cblxuXG5mdW5jdGlvbiBfX2dldE1vbmFjb0luc3RhbmNlKCkge1xuICByZXR1cm4gZ2V0U3RhdGUoZnVuY3Rpb24gKF9yZWY0KSB7XG4gICAgdmFyIG1vbmFjbyA9IF9yZWY0Lm1vbmFjbztcbiAgICByZXR1cm4gbW9uYWNvO1xuICB9KTtcbn1cblxudmFyIHdyYXBwZXJQcm9taXNlID0gbmV3IFByb21pc2UoZnVuY3Rpb24gKHJlc29sdmUsIHJlamVjdCkge1xuICByZXR1cm4gc2V0U3RhdGUoe1xuICAgIHJlc29sdmU6IHJlc29sdmUsXG4gICAgcmVqZWN0OiByZWplY3RcbiAgfSk7XG59KTtcbnZhciBsb2FkZXIgPSB7XG4gIGNvbmZpZzogY29uZmlnLFxuICBpbml0OiBpbml0LFxuICBfX2dldE1vbmFjb0luc3RhbmNlOiBfX2dldE1vbmFjb0luc3RhbmNlXG59O1xuXG5leHBvcnQgZGVmYXVsdCBsb2FkZXI7XG4iLCAiLy8gaHR0cHM6Ly9naXRodWIuY29tL2xpdmVib29rLWRldi9saXZlYm9vay9ibG9iLzg1MzJiYzMzNGJkY2YzYzU3ZmFiOWI2OTQ2NjZlNjA5ODc3ZDI3OWYvYXNzZXRzL2pzL2hvb2tzL2NlbGxfZWRpdG9yL2xpdmVfZWRpdG9yLmpzXG5cbmltcG9ydCBsb2FkZXIgZnJvbSBcIkBtb25hY28tZWRpdG9yL2xvYWRlclwiXG5cbmNsYXNzIENvZGVFZGl0b3Ige1xuICBjb25zdHJ1Y3RvcihlbCwgcGF0aCwgdmFsdWUsIG9wdHMpIHtcbiAgICB0aGlzLmVsID0gZWxcbiAgICB0aGlzLnBhdGggPSBwYXRoXG4gICAgdGhpcy52YWx1ZSA9IHZhbHVlXG4gICAgdGhpcy5vcHRzID0gb3B0c1xuICAgIC8vIGh0dHBzOi8vbWljcm9zb2Z0LmdpdGh1Yi5pby9tb25hY28tZWRpdG9yL2RvY3MuaHRtbCNpbnRlcmZhY2VzL2VkaXRvci5JU3RhbmRhbG9uZUNvZGVFZGl0b3IuaHRtbFxuICAgIHRoaXMuc3RhbmRhbG9uZV9jb2RlX2VkaXRvciA9IG51bGxcbiAgICB0aGlzLl9vbk1vdW50ID0gW11cbiAgfVxuXG4gIGlzTW91bnRlZCgpIHtcbiAgICByZXR1cm4gISF0aGlzLnN0YW5kYWxvbmVfY29kZV9lZGl0b3JcbiAgfVxuXG4gIG1vdW50KCkge1xuICAgIGlmICh0aGlzLmlzTW91bnRlZCgpKSB7XG4gICAgICB0aHJvdyBuZXcgRXJyb3IoXCJUaGUgbW9uYWNvIGVkaXRvciBpcyBhbHJlYWR5IG1vdW50ZWRcIilcbiAgICB9XG5cbiAgICB0aGlzLl9tb3VudEVkaXRvcigpXG4gIH1cblxuICBvbk1vdW50KGNhbGxiYWNrKSB7XG4gICAgdGhpcy5fb25Nb3VudC5wdXNoKGNhbGxiYWNrKVxuICB9XG5cbiAgZGlzcG9zZSgpIHtcbiAgICBpZiAodGhpcy5pc01vdW50ZWQoKSkge1xuICAgICAgY29uc3QgbW9kZWwgPSB0aGlzLnN0YW5kYWxvbmVfY29kZV9lZGl0b3IuZ2V0TW9kZWwoKVxuXG4gICAgICBpZiAobW9kZWwpIHtcbiAgICAgICAgbW9kZWwuZGlzcG9zZSgpXG4gICAgICB9XG5cbiAgICAgIHRoaXMuc3RhbmRhbG9uZV9jb2RlX2VkaXRvci5kaXNwb3NlKClcbiAgICB9XG4gIH1cblxuICBfbW91bnRFZGl0b3IoKSB7XG4gICAgdGhpcy5vcHRzLnZhbHVlID0gdGhpcy52YWx1ZVxuXG4gICAgbG9hZGVyLmluaXQoKS50aGVuKChtb25hY28pID0+IHtcbiAgICAgIGxldCBtb2RlbFVyaSA9IG1vbmFjby5VcmkucGFyc2UodGhpcy5wYXRoKVxuICAgICAgbGV0IGxhbmd1YWdlID0gdGhpcy5vcHRzLmxhbmd1YWdlXG4gICAgICBsZXQgbW9kZWwgPSBtb25hY28uZWRpdG9yLmNyZWF0ZU1vZGVsKHRoaXMudmFsdWUsIGxhbmd1YWdlLCBtb2RlbFVyaSlcblxuICAgICAgdGhpcy5vcHRzLmxhbmd1YWdlID0gdW5kZWZpbmVkXG4gICAgICB0aGlzLm9wdHMubW9kZWwgPSBtb2RlbFxuICAgICAgdGhpcy5zdGFuZGFsb25lX2NvZGVfZWRpdG9yID0gbW9uYWNvLmVkaXRvci5jcmVhdGUodGhpcy5lbCwgdGhpcy5vcHRzKVxuXG4gICAgICB0aGlzLl9vbk1vdW50LmZvckVhY2goKGNhbGxiYWNrKSA9PiBjYWxsYmFjayhtb25hY28pKVxuICAgIH0pXG4gIH1cbn1cblxuZXhwb3J0IGRlZmF1bHQgQ29kZUVkaXRvclxuIiwgImltcG9ydCBDb2RlRWRpdG9yIGZyb20gXCIuLi9lZGl0b3IvY29kZV9lZGl0b3JcIlxuXG5jb25zdCBDb2RlRWRpdG9ySG9vayA9IHtcbiAgbW91bnRlZCgpIHtcbiAgICAvLyBUT0RPOiB2YWxpZGF0ZSBkYXRhc2V0XG4gICAgY29uc3Qgb3B0cyA9IEpTT04ucGFyc2UodGhpcy5lbC5kYXRhc2V0Lm9wdHMpXG4gICAgdGhpcy5jb2RlRWRpdG9yID0gbmV3IENvZGVFZGl0b3IoXG4gICAgICB0aGlzLmVsLFxuICAgICAgdGhpcy5lbC5kYXRhc2V0LnBhdGgsXG4gICAgICB0aGlzLmVsLmRhdGFzZXQudmFsdWUsXG4gICAgICBvcHRzXG4gICAgKVxuXG4gICAgdGhpcy5jb2RlRWRpdG9yLm9uTW91bnQoKG1vbmFjbykgPT4ge1xuICAgICAgdGhpcy5lbC5kaXNwYXRjaEV2ZW50KFxuICAgICAgICBuZXcgQ3VzdG9tRXZlbnQoXCJsbWU6ZWRpdG9yX21vdW50ZWRcIiwge1xuICAgICAgICAgIGRldGFpbDogeyBob29rOiB0aGlzLCBlZGl0b3I6IHRoaXMuY29kZUVkaXRvciB9LFxuICAgICAgICAgIGJ1YmJsZXM6IHRydWUsXG4gICAgICAgIH0pXG4gICAgICApXG5cbiAgICAgIHRoaXMuaGFuZGxlRXZlbnQoXG4gICAgICAgIFwibG1lOmNoYW5nZV9sYW5ndWFnZTpcIiArIHRoaXMuZWwuZGF0YXNldC5wYXRoLFxuICAgICAgICAoZGF0YSkgPT4ge1xuICAgICAgICAgIGNvbnN0IG1vZGVsID0gdGhpcy5jb2RlRWRpdG9yLnN0YW5kYWxvbmVfY29kZV9lZGl0b3IuZ2V0TW9kZWwoKVxuXG4gICAgICAgICAgaWYgKG1vZGVsLmdldExhbmd1YWdlSWQoKSAhPT0gZGF0YS5taW1lVHlwZU9yTGFuZ3VhZ2VJZCkge1xuICAgICAgICAgICAgbW9uYWNvLmVkaXRvci5zZXRNb2RlbExhbmd1YWdlKG1vZGVsLCBkYXRhLm1pbWVUeXBlT3JMYW5ndWFnZUlkKVxuICAgICAgICAgIH1cbiAgICAgICAgfVxuICAgICAgKVxuXG4gICAgICB0aGlzLmhhbmRsZUV2ZW50KFwibG1lOnNldF92YWx1ZTpcIiArIHRoaXMuZWwuZGF0YXNldC5wYXRoLCAoZGF0YSkgPT4ge1xuICAgICAgICB0aGlzLmNvZGVFZGl0b3Iuc3RhbmRhbG9uZV9jb2RlX2VkaXRvci5zZXRWYWx1ZShkYXRhLnZhbHVlKVxuICAgICAgfSlcblxuICAgICAgdGhpcy5lbC5xdWVyeVNlbGVjdG9yQWxsKFwidGV4dGFyZWFcIikuZm9yRWFjaCgodGV4dGFyZWEpID0+IHtcbiAgICAgICAgdGV4dGFyZWEuc2V0QXR0cmlidXRlKFxuICAgICAgICAgIFwibmFtZVwiLFxuICAgICAgICAgIFwibGl2ZV9tb25hY29fZWRpdG9yW1wiICsgdGhpcy5lbC5kYXRhc2V0LnBhdGggKyBcIl1cIlxuICAgICAgICApXG4gICAgICB9KVxuXG4gICAgICB0aGlzLmVsLnJlbW92ZUF0dHJpYnV0ZShcImRhdGEtdmFsdWVcIilcbiAgICAgIHRoaXMuZWwucmVtb3ZlQXR0cmlidXRlKFwiZGF0YS1vcHRzXCIpXG4gICAgfSlcblxuICAgIGlmICghdGhpcy5jb2RlRWRpdG9yLmlzTW91bnRlZCgpKSB7XG4gICAgICB0aGlzLmNvZGVFZGl0b3IubW91bnQoKVxuICAgIH1cbiAgfSxcblxuICBkZXN0cm95ZWQoKSB7XG4gICAgaWYgKHRoaXMuY29kZUVkaXRvcikge1xuICAgICAgdGhpcy5jb2RlRWRpdG9yLmRpc3Bvc2UoKVxuICAgIH1cbiAgfSxcbn1cblxuZXhwb3J0IHsgQ29kZUVkaXRvckhvb2sgfVxuIiwgIi8vIEJlYWNvbiBBZG1pblxuLy9cbi8vIE5vdGU6XG4vLyAxLiBydW4gYG1peCBhc3NldHMuYnVpbGRgIHRvIGRpc3RyaWJ1dGUgdXBkYXRlZCBzdGF0aWMgYXNzZXRzXG4vLyAyLiBwaG9lbml4IGpzIGxvYWRlZCBmcm9tIHRoZSBob3N0IGFwcGxpY2F0aW9uXG5cbmltcG9ydCB7IENvZGVFZGl0b3JIb29rIH0gZnJvbSBcIi4uLy4uL2RlcHMvbGl2ZV9tb25hY29fZWRpdG9yL3ByaXYvc3RhdGljL2xpdmVfbW9uYWNvX2VkaXRvci5lc21cIlxuXG5sZXQgSG9va3MgPSB7fVxuSG9va3MuQ29kZUVkaXRvckhvb2sgPSBDb2RlRWRpdG9ySG9va1xuXG53aW5kb3cuYWRkRXZlbnRMaXN0ZW5lcihcImxtZTplZGl0b3JfbW91bnRlZFwiLCAoZXYpID0+IHtcbiAgY29uc3QgaG9vayA9IGV2LmRldGFpbC5ob29rXG4gIGNvbnN0IGVkaXRvciA9IGV2LmRldGFpbC5lZGl0b3Iuc3RhbmRhbG9uZV9jb2RlX2VkaXRvclxuICBjb25zdCBldmVudE5hbWUgPSBldi5kZXRhaWwuZWRpdG9yLnBhdGggKyBcIl9lZGl0b3JfbG9zdF9mb2N1c1wiXG5cbiAgZWRpdG9yLm9uRGlkQmx1ckVkaXRvcldpZGdldCgoKSA9PiB7XG4gICAgaG9vay5wdXNoRXZlbnQoZXZlbnROYW1lLCB7IHZhbHVlOiBlZGl0b3IuZ2V0VmFsdWUoKSB9KVxuICB9KVxufSlcblxubGV0IHNvY2tldFBhdGggPVxuICBkb2N1bWVudC5xdWVyeVNlbGVjdG9yKFwiaHRtbFwiKS5nZXRBdHRyaWJ1dGUoXCJwaHgtc29ja2V0XCIpIHx8IFwiL2xpdmVcIlxubGV0IGNzcmZUb2tlbiA9IGRvY3VtZW50XG4gIC5xdWVyeVNlbGVjdG9yKFwibWV0YVtuYW1lPSdjc3JmLXRva2VuJ11cIilcbiAgLmdldEF0dHJpYnV0ZShcImNvbnRlbnRcIilcbmxldCBsaXZlU29ja2V0ID0gbmV3IExpdmVWaWV3LkxpdmVTb2NrZXQoc29ja2V0UGF0aCwgUGhvZW5peC5Tb2NrZXQsIHtcbiAgaG9va3M6IEhvb2tzLFxuICBwYXJhbXM6IHsgX2NzcmZfdG9rZW46IGNzcmZUb2tlbiB9LFxufSlcbmxpdmVTb2NrZXQuY29ubmVjdCgpXG53aW5kb3cubGl2ZVNvY2tldCA9IGxpdmVTb2NrZXRcbiJdLAogICJtYXBwaW5ncyI6ICI7O0FBQUEsV0FBUyxnQkFBZ0IsS0FBSyxLQUFLLE9BQU87QUFDeEMsUUFBSSxPQUFPLEtBQUs7QUFDZCxhQUFPLGVBQWUsS0FBSyxLQUFLO1FBQzlCO1FBQ0EsWUFBWTtRQUNaLGNBQWM7UUFDZCxVQUFVO01BQ1osQ0FBQztJQUNILE9BQU87QUFDTCxVQUFJLEdBQUcsSUFBSTtJQUNiO0FBRUEsV0FBTztFQUNUO0FBRUEsV0FBUyxRQUFRLFFBQVEsZ0JBQWdCO0FBQ3ZDLFFBQUksT0FBTyxPQUFPLEtBQUssTUFBTTtBQUU3QixRQUFJLE9BQU8sdUJBQXVCO0FBQ2hDLFVBQUksVUFBVSxPQUFPLHNCQUFzQixNQUFNO0FBQ2pELFVBQUk7QUFBZ0Isa0JBQVUsUUFBUSxPQUFPLFNBQVUsS0FBSztBQUMxRCxpQkFBTyxPQUFPLHlCQUF5QixRQUFRLEdBQUcsRUFBRTtRQUN0RCxDQUFD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QUNiLFFBQU0saUJBQWlCO0FBRXZCLFNBQU8saUJBQWlCLHNCQUFzQixDQUFDLE9BQU87QUFDcEQsVUFBTSxPQUFPLEdBQUcsT0FBTztBQUN2QixVQUFNLFNBQVMsR0FBRyxPQUFPLE9BQU87QUFDaEMsVUFBTSxZQUFZLEdBQUcsT0FBTyxPQUFPLE9BQU87QUFFMUMsV0FBTyxzQkFBc0IsTUFBTTtBQUNqQyxXQUFLLFVBQVUsV0FBVyxFQUFFLE9BQU8sT0FBTyxTQUFTLEVBQUUsQ0FBQztBQUFBLElBQ3hELENBQUM7QUFBQSxFQUNILENBQUM7QUFFRCxNQUFJLGFBQ0YsU0FBUyxjQUFjLE1BQU0sRUFBRSxhQUFhLFlBQVksS0FBSztBQUMvRCxNQUFJLFlBQVksU0FDYixjQUFjLHlCQUF5QixFQUN2QyxhQUFhLFNBQVM7QUFDekIsTUFBSSxhQUFhLElBQUksU0FBUyxXQUFXLFlBQVksUUFBUSxRQUFRO0FBQUEsSUFDbkUsT0FBTztBQUFBLElBQ1AsUUFBUSxFQUFFLGFBQWEsVUFBVTtBQUFBLEVBQ25DLENBQUM7QUFDRCxhQUFXLFFBQVE7QUFDbkIsU0FBTyxhQUFhOyIsCiAgIm5hbWVzIjogWyJfZGVmaW5lUHJvcGVydHkiLCAib3duS2V5cyIsICJfb2JqZWN0U3ByZWFkMiIsICJlcnJvck1lc3NhZ2VzIiwgImdldFN0YXRlIiwgInN0YXRlIiwgInNldFN0YXRlIiwgImN1cnJ5IiwgImlzT2JqZWN0IiwgImNvbmZpZyIsICJlcnJvckhhbmRsZXIiLCAidGhyb3dFcnJvciIsICJ2YWxpZGF0b3JzIiwgImNvbXBvc2UiLCAiY29uZmlndXJlTG9hZGVyIiwgInJlcXVpcmUiXQp9Cg==
