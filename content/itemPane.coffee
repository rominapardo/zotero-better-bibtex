debug = require('./debug.coffee')

KeyManager = require('./keymanager.coffee')
DB = require('./db/main.coffee')

id = 'zotero-better-bibtex-itempane-citekey'

class ItemPane
  load: ->
    @citekeys = DB.getCollection('citekey')

    if !ZoteroItemPane.BetterBibTeX
      # prevent multi-patching
      ZoteroItemPane.BetterBibTeX = true

      ZoteroItemPane.viewItem = ((original, self) ->
        return Zotero.Promise.coroutine((item, mode, index) ->
          yield original.apply(@, arguments)

          self.addCitekeyRow(item.id) if index == 0 # details pane

          self.DOMobserver = new MutationObserver((mutations) ->
            self.addCitekeyRow(item.id)
            return
          )
          self.DOMobserver.observe(document.getElementById('dynamic-fields'), {attributes: true, subtree: true, childList: true})
          self.citekeyObserver = @citekeys.on('update', (citekey) ->
            self.addCitekeyRow(item.id) if citekey.itemID == item.id
            return
          ) if @citekeys

          return
        )
      )(ZoteroItemPane.viewItem, @)

    @addCitekeyRow()

    return

  unload: ->
    @DOMobserver.disconnect() if @DOMobserver
    @citekeys.removeListener(@citekeyObserver) if @citekeys
    return

  addCitekeyRow: (itemID) ->
    if document.getElementById(id)
      debug('ItemPane: citekey row already present')
      return

    if !(display = document.getElementById(id))
      template = document.getElementById(id + '-template')
      row = template.cloneNode(true)
      row.setAttribute('id', id + '-row')
      row.setAttribute('hidden', false)
      display = row.getElementsByClassName('better-bibtex-citekey-display')[0]
      display.setAttribute('id', id)

      fields = document.getElementById('dynamic-fields')
      if fields.childNodes.length > 1
        fields.insertBefore(row, fields.childNodes[1])
      else
        fields.appendChild(row)

      debug('ItemPane: citekey row added')

    if itemID?
      try
        citekey = KeyManager.get(itemID)
        display.value = citekey.citekey
        display.classList[if citekey.pinned then 'remove' else 'add']('citekey-dynamic')

    return

module.exports = new ItemPane()

window.addEventListener('load', (-> module.exports.load()), false)
window.addEventListener('unload', (-> module.exports.unload()), false)

# otherwise this entry point won't be reloaded: https://github.com/webpack/webpack/issues/156
delete require.cache[module.id]