import loader from '@monaco-editor/loader'

const BeaconEditor = {
  mounted() {
    loader.init().then((monaco) => {
      monaco.editor.create(document.getElementById('editor'), {
        value: ['## Title', '', 'TODO'].join('\n'),
        language: 'markdown',
      })
    })
  },
}

export default BeaconEditor
