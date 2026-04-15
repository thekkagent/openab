#!/usr/bin/env bash
# Helm template tests for openab chart — bot messages config
set -euo pipefail

CHART_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== Helm template tests: allowBotMessages & trustedBotIds ==="
echo

# ---------- Test 1: allowBotMessages = "mentions" renders correctly ----------
echo "[Test 1] allowBotMessages = mentions renders correctly"
OUT=$(helm template test "$CHART_DIR" \
  --set 'agents.kiro.discord.allowBotMessages=mentions' 2>&1)
if echo "$OUT" | grep -q 'allow_bot_messages = "mentions"'; then
  pass "allow_bot_messages = \"mentions\" found in rendered output"
else
  fail "allow_bot_messages = \"mentions\" not found in rendered output"
  echo "$OUT"
fi

# ---------- Test 2: allowBotMessages = "all" renders correctly ----------
echo "[Test 2] allowBotMessages = all renders correctly"
OUT=$(helm template test "$CHART_DIR" \
  --set 'agents.kiro.discord.allowBotMessages=all' 2>&1)
if echo "$OUT" | grep -q 'allow_bot_messages = "all"'; then
  pass "allow_bot_messages = \"all\" found in rendered output"
else
  fail "allow_bot_messages = \"all\" not found in rendered output"
  echo "$OUT"
fi

# ---------- Test 3: allowBotMessages = "off" renders correctly ----------
echo "[Test 3] allowBotMessages = off renders correctly"
OUT=$(helm template test "$CHART_DIR" \
  --set 'agents.kiro.discord.allowBotMessages=off' 2>&1)
if echo "$OUT" | grep -q 'allow_bot_messages = "off"'; then
  pass "allow_bot_messages = \"off\" found in rendered output"
else
  fail "allow_bot_messages = \"off\" not found in rendered output"
  echo "$OUT"
fi

# ---------- Test 4: invalid allowBotMessages value fails ----------
echo "[Test 4] invalid allowBotMessages value is rejected"
OUT=$(helm template test "$CHART_DIR" \
  --set 'agents.kiro.discord.allowBotMessages=yolo' 2>&1) && RC=0 || RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q 'must be one of: off, mentions, all'; then
  pass "invalid value 'yolo' rejected with correct error message"
else
  fail "invalid value 'yolo' was not rejected or error message is wrong"
  echo "$OUT"
fi

# ---------- Test 5: trustedBotIds renders correctly ----------
echo "[Test 5] trustedBotIds renders correctly"
OUT=$(helm template test "$CHART_DIR" \
  --set-string 'agents.kiro.discord.trustedBotIds[0]=123456789012345678' \
  --set-string 'agents.kiro.discord.trustedBotIds[1]=987654321098765432' \
  --set 'agents.kiro.discord.allowBotMessages=mentions' 2>&1)
if echo "$OUT" | grep -q 'trusted_bot_ids = \["123456789012345678","987654321098765432"\]'; then
  pass "trustedBotIds rendered as JSON array"
else
  fail "trustedBotIds not rendered correctly"
  echo "$OUT"
fi

# ---------- Test 6: mangled trustedBotId (--set not --set-string) fails ----------
echo "[Test 6] mangled snowflake ID via --set is rejected"
OUT=$(helm template test "$CHART_DIR" \
  --set 'agents.kiro.discord.trustedBotIds[0]=1.234567890123457e+17' 2>&1) && RC=0 || RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q 'mangled ID'; then
  pass "mangled snowflake ID rejected with correct error"
else
  fail "mangled snowflake ID was not rejected"
  echo "$OUT"
fi

# ---------- Test 7: default allowBotMessages="off" does not omit the field ----------
echo "[Test 7] default values render allow_bot_messages"
OUT=$(helm template test "$CHART_DIR" 2>&1)
if echo "$OUT" | grep -q 'allow_bot_messages = "off"'; then
  pass "default allow_bot_messages = \"off\" rendered"
else
  fail "default allow_bot_messages = \"off\" not found in rendered output"
  echo "$OUT"
fi

# ---------- Test 8: global imagePullSecrets render into pod spec ----------
echo "[Test 8] global imagePullSecrets render into pod spec"
OUT=$(helm template test "$CHART_DIR" \
  --set-string 'imagePullSecrets[0]=regcred' 2>&1)
if echo "$OUT" | grep -q 'imagePullSecrets:' && echo "$OUT" | grep -Eq 'name: "?regcred"?'; then
  pass "global imagePullSecrets rendered"
else
  fail "global imagePullSecrets not rendered"
  echo "$OUT"
fi

# ---------- Test 9: per-agent imagePullPolicy overrides global default ----------
echo "[Test 9] per-agent imagePullPolicy overrides global default"
OUT=$(helm template test "$CHART_DIR" \
  --set 'image.pullPolicy=IfNotPresent' \
  --set 'agents.kiro.imagePullPolicy=Always' 2>&1)
if echo "$OUT" | grep -q 'imagePullPolicy: Always'; then
  pass "per-agent imagePullPolicy rendered"
else
  fail "per-agent imagePullPolicy not rendered"
  echo "$OUT"
fi

# ---------- Test 10: initContainers render into pod spec ----------
echo "[Test 10] initContainers render into pod spec"
OUT=$(helm template test "$CHART_DIR" \
  --set 'agents.kiro.initContainers[0].name=setup' \
  --set 'agents.kiro.initContainers[0].image=busybox:1.36' \
  --set 'agents.kiro.initContainers[0].command[0]=sh' \
  --set 'agents.kiro.initContainers[0].command[1]=-c' \
  --set 'agents.kiro.initContainers[0].command[2]=echo setup' 2>&1)
if echo "$OUT" | grep -q 'initContainers:' && echo "$OUT" | grep -q 'name: setup'; then
  pass "initContainers rendered"
else
  fail "initContainers not rendered"
  echo "$OUT"
fi

# ---------- Test 11: sidecars render into pod spec ----------
echo "[Test 11] sidecars render into pod spec"
OUT=$(helm template test "$CHART_DIR" \
  --set 'agents.kiro.sidecars[0].name=logtail' \
  --set 'agents.kiro.sidecars[0].image=busybox:1.36' 2>&1)
if echo "$OUT" | grep -q 'name: logtail' && echo "$OUT" | grep -q 'image: busybox:1.36'; then
  pass "sidecars rendered"
else
  fail "sidecars not rendered"
  echo "$OUT"
fi

# ---------- Test 12: extra volumes and mounts render ----------
echo "[Test 12] extra volumes and mounts render"
OUT=$(helm template test "$CHART_DIR" \
  --set 'agents.kiro.extraVolumes[0].name=scratch' \
  --set 'agents.kiro.extraVolumes[0].emptyDir={}' \
  --set 'agents.kiro.extraVolumeMounts[0].name=scratch' \
  --set 'agents.kiro.extraVolumeMounts[0].mountPath=/scratch' 2>&1)
if echo "$OUT" | grep -q 'mountPath: /scratch' && echo "$OUT" | grep -q 'name: scratch'; then
  pass "extra volumes and mounts rendered"
else
  fail "extra volumes and mounts not rendered"
  echo "$OUT"
fi

# ---------- Test 13: probes, lifecycle and serviceAccountName render ----------
echo "[Test 13] probes, lifecycle and serviceAccountName render"
OUT=$(helm template test "$CHART_DIR" \
  --set 'agents.kiro.serviceAccountName=openab-agent' \
  --set 'agents.kiro.livenessProbe.httpGet.path=/healthz' \
  --set 'agents.kiro.livenessProbe.httpGet.port=8080' \
  --set 'agents.kiro.readinessProbe.httpGet.path=/readyz' \
  --set 'agents.kiro.readinessProbe.httpGet.port=8080' \
  --set 'agents.kiro.startupProbe.exec.command[0]=pgrep' \
  --set 'agents.kiro.startupProbe.exec.command[1]=openab' \
  --set 'agents.kiro.lifecycle.preStop.exec.command[0]=sh' \
  --set 'agents.kiro.lifecycle.preStop.exec.command[1]=-c' \
  --set 'agents.kiro.lifecycle.preStop.exec.command[2]=sleep 1' 2>&1)
if echo "$OUT" | grep -q 'serviceAccountName: openab-agent' && \
   echo "$OUT" | grep -q 'livenessProbe:' && \
   echo "$OUT" | grep -q 'readinessProbe:' && \
   echo "$OUT" | grep -q 'startupProbe:' && \
   echo "$OUT" | grep -q 'lifecycle:'; then
  pass "serviceAccountName, probes and lifecycle rendered"
else
  fail "serviceAccountName, probes or lifecycle not rendered"
  echo "$OUT"
fi

# ---------- Test 14: pod annotations and labels render ----------
echo "[Test 14] pod annotations and labels render"
OUT=$(helm template test "$CHART_DIR" \
  --set 'podAnnotations.team=platform' \
  --set 'podLabels.tier=agents' \
  --set 'agents.kiro.podAnnotations.trace=enabled' \
  --set 'agents.kiro.podLabels.agent=kiro' 2>&1)
if echo "$OUT" | grep -q 'team: platform' && \
   echo "$OUT" | grep -q 'trace: enabled' && \
   echo "$OUT" | grep -q 'tier: agents' && \
   echo "$OUT" | grep -q 'agent: kiro'; then
  pass "pod annotations and labels rendered"
else
  fail "pod annotations or labels not rendered"
  echo "$OUT"
fi

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
