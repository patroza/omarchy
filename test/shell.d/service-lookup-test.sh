#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

run_node_test <<'JS'
const lookup = requireFromRoot('shell/services/ServiceLookup.js')

// resolveEnabledId() as PluginRegistry implements it: a built-in id maps to the
// enabled clone that declares `omarchy.clonedFrom`, and anything else maps to
// itself.
function resolver(clones) {
  return function(key) { return clones[key] || key }
}

const none = resolver({})
const cloned = resolver({ 'omarchy.notifications': 'local.notifications' })

assertEqual(
  lookup.resolveServiceId({ 'omarchy.notifications': {} }, 'omarchy.notifications', none),
  'omarchy.notifications',
  'service lookup answers a built-in id from its own service'
)

assertEqual(
  lookup.resolveServiceId({ 'local.notifications': {} }, 'omarchy.notifications', cloned),
  'local.notifications',
  'service lookup routes a built-in id to the enabled clone'
)

// The regression this guards: _services is keyed by each plugin's own manifest
// id, so before the clone was consulted this returned nothing and every caller
// of firstPartyServiceFor() silently no-opped.
assertEqual(
  lookup.resolveServiceId({ 'local.notifications': {} }, 'omarchy.notifications', none),
  '',
  'service lookup finds nothing when no clone claims the built-in id'
)

// An enabled built-in keeps answering for itself even while a clone exists, so
// re-enabling the source does not strand callers on a stale clone.
assertEqual(
  lookup.resolveServiceId(
    { 'omarchy.notifications': {}, 'local.notifications': {} },
    'omarchy.notifications',
    cloned
  ),
  'omarchy.notifications',
  'service lookup prefers an enabled built-in over its clone'
)

assertEqual(
  lookup.resolveServiceId({ 'local.notifications': {} }, 'local.notifications', cloned),
  'local.notifications',
  'service lookup answers a clone asked for by its own id'
)

// A clone that resolveEnabledId points at but that has no loaded service must
// not be handed back as if it were live.
assertEqual(
  lookup.resolveServiceId({}, 'omarchy.notifications', cloned),
  '',
  'service lookup rejects a resolved id with no loaded service'
)

assertEqual(lookup.resolveServiceId({}, '', none), '', 'service lookup rejects an empty id')
assertEqual(lookup.resolveServiceId({}, null, none), '', 'service lookup rejects a null id')
assertEqual(
  lookup.resolveServiceId({ 'omarchy.notifications': {} }, 'omarchy.notifications', null),
  'omarchy.notifications',
  'service lookup still answers direct hits without a resolver'
)
assertEqual(
  lookup.resolveServiceId({ 'local.notifications': {} }, 'omarchy.notifications', null),
  '',
  'service lookup cannot reach a clone without a resolver'
)
JS

# The QML side must actually go through the helper, otherwise the coverage above
# is testing a module nothing calls.
service_for=$(sed -n '/^  function serviceFor(/,/^  }/p' "$ROOT/shell/shell.qml")

grep -q 'ServiceLookup.resolveServiceId' <<<"$service_for" ||
  fail "serviceFor() resolves through ServiceLookup"
grep -q 'pluginRegistry.resolveEnabledId' <<<"$service_for" ||
  fail "serviceFor() consults the plugin registry for clones"

pass "service lookup resolves cloned plugin services"
