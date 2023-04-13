/*
 * Beacon Admin js build
 *
 * Refs:
 * https://github.com/microsoft/monaco-editor/blob/689a4b89b202ea0125732087e5e6aa189e483ac0/samples/browser-esm-esbuild/build.js
 * https://github.com/livebook-dev/livebook/blob/a020ea85c58da71d918a5509353d798245b939b6/assets/js/hooks/cell_editor/live_editor/monaco.js
 */

const esbuild = require('esbuild')

const args = process.argv.slice(2)
const watch = args.includes('--watch')
const deploy = args.includes('--deploy')

async function buildEditor() {
  const workerEntryPoints = [
    'vs/language/json/json.worker.js',
    'vs/language/css/css.worker.js',
    'vs/language/html/html.worker.js',
    'vs/language/typescript/ts.worker.js',
    'vs/editor/editor.worker.js',
  ]

  const context = await esbuild.context({
    entryPoints: workerEntryPoints.map((entry) => `./node_modules/monaco-editor/esm/${entry}`),
    bundle: true,
    minify: true,
    format: 'iife',
    outbase: './node_modules/monaco-editor/esm/',
    outdir: '../priv/static',
    logLevel: 'info',
  })

  await context.rebuild()
  await context.dispose()
}

async function buildBeacon() {
  let opts = {
    entryPoints: ['js/beacon_admin.js'],
    bundle: true,
    format: 'iife',
    outdir: '../priv/static',
    logLevel: 'info',
    loader: {
      '.ttf': 'file',
    },
  }

  if (deploy) {
    opts = {
      ...opts,
      minify: true,
    }
  }

  if (watch) {
    opts = {
      ...opts,
      sourcemap: 'inline',
    }

    const context = await esbuild.context(opts)
    await context.watch()
  } else {
    const context = await esbuild.context(opts)
    await context.rebuild()
    await context.dispose()
  }
}

buildEditor()
buildBeacon()
