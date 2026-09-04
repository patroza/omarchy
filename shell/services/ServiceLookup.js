// Which key in the shell's `_services` map answers a request for `requestedId`.
//
// `_services` is keyed by each plugin's own manifest id, because _syncServices()
// instantiates over installedPlugins and skips the disabled ones. So a caller
// asking for a built-in id finds nothing the moment that built-in has been
// disabled in favour of a clone -- even though PluginRegistry.resolveEnabledId()
// exists precisely to route built-in ids to the enabled clone, and the summon /
// toggle / call / hide entry points already use it.
//
// Direct hit first: an enabled built-in keeps answering for itself, and the
// common case stays a single lookup.
function resolveServiceId(services, requestedId, resolveEnabledId) {
  var map = services || {}
  var key = String(requestedId === undefined || requestedId === null ? "" : requestedId)
  if (key === "") return ""
  if (map[key]) return key

  if (typeof resolveEnabledId !== "function") return ""
  var resolved = resolveEnabledId(key)
  resolved = String(resolved === undefined || resolved === null ? "" : resolved)
  if (resolved === "" || resolved === key) return ""

  return map[resolved] ? resolved : ""
}

if (typeof module !== "undefined") {
  module.exports = {
    resolveServiceId: resolveServiceId
  }
}
