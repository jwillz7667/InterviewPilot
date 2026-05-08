# Runbook: StoreKit notification / entitlement drift

## Symptoms

- User reports "I paid but I'm still on Free tier."
- Sentry: `billing.notification.unverified` or `billing.notification.parse_failed` events.
- Apple Server Notifications dashboard (App Store Connect → Apps → InterviewPilot → App Information → App Store Server Notifications) shows non-2xx delivery rate >1%.
- Daily reconciliation job emits `billing.entitlement.drift_detected`.

## Triage

1. **Identify scope** — single user or many?
2. **Pull the user's recent events**:
   ```sh
   railway run psql $DATABASE_URL -c "
     SELECT id, type, environment, status, processedAt, errorMessage
     FROM app_store_notifications
     WHERE userId = '<user-id>'
     ORDER BY createdAt DESC LIMIT 20;"
   ```
3. **Check the user's App Store transaction history** — App Store Connect → Users → search by email → Subscriptions tab. If Apple shows an active sub but our DB shows tier=FREE, we have drift.
4. **Check webhook endpoint health** — `curl -sS https://api.interviewace.app/api/v1/billing/app-store/notifications -X POST -H "Content-Type: application/json" -d '{}'` should return 400 (not 5xx). If 5xx, the webhook itself is broken.

## Resolution

### Single-user drift (manual reconciliation)

1. Trigger client-side sync — ask the user to sign out + sign in. The iOS `restorePurchases()` flow calls `AppStore.sync()` + `POST /api/v1/billing/app-store/sync` which re-verifies all active transactions.
2. If that fails, manual fix:
   ```sh
   railway run npx tsx backend/scripts/reconcile-user.ts --userId=<id>
   ```
   Script lives in `backend/scripts/reconcile-user.ts` (see D5 reconciliation cron).

### Many-user drift

1. **Check if Apple's webhook deliveries are failing** — App Store Connect → Notifications History. If retries are exhausted on many notifications, our endpoint was down or returned non-2xx.
2. **Run the bulk reconciliation script**:
   ```sh
   railway run npx tsx backend/scripts/reconcile-entitlements.ts --since=2h
   ```
   This calls Apple's `getAllSubscriptionStatuses` for every user with `tier != FREE` whose entitlement was last verified >2 hours ago.
3. **Communicate** if it's >50 users — email via SendGrid template `entitlement-restored`.

### Webhook endpoint returning 5xx

Treat as deployment incident — see [deploy.md](deploy.md). Revert the bad commit; reconciliation cron will sweep up missed notifications within an hour.

### JWS verification failing

If `processAppStoreNotification` keeps throwing on JWS validation:

1. Check Apple root CA bundle isn't stale — `@apple/app-store-server-library` ships with current roots, but if you pinned an old version, upgrade.
2. Check `APP_STORE_KEY_ID` / `APP_STORE_ISSUER_ID` / `APP_STORE_BUNDLE_ID` env vars haven't drifted.
3. Test mode: Apple sends notifications from sandbox to prod webhooks if your build used a sandbox receipt. Filter by `environment` in our `processAppStoreNotification`.

## Postmortem checklist

- How many users affected, and total revenue at risk during the drift window?
- Was the webhook endpoint actually returning 5xx, or were notifications dropping for other reasons (rate-limit, body-size)?
- Did the hourly reconciliation cron catch it? If so, MTTR was acceptable. If not, review the cron's drift detection.
- Were any users charged but never granted entitlement? (Issue refunds via App Store Connect; we cannot refund directly.)
