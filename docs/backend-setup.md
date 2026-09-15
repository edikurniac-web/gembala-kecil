# Firebase + Cloudflare foundation

## Responsibility split

- Firebase Authentication identifies a parent account. Free stories remain usable without authentication.
- Cloud Firestore stores parent metadata, child profiles, reading progress, and purchase entitlements.
- Entitlements are readable by the owning parent but writable only by trusted backend code after purchase verification.
- Cloudflare R2 stores the public content catalog, square illustrations, narration MP3 files, and word timing JSON.
- A Cloudflare Worker serves public content and protects backoffice writes with a server-side secret.

## Firestore shape

```text
parents/{uid}
  displayName, email, createdAt, updatedAt
  children/{childId}
    name, avatarKey, createdAt, updatedAt
    progress/{storyId}
      completed, lastPage, updatedAt
  entitlements/{productId}
    active, source, expiresAt, updatedAt
```

One Firebase user owns one parent document and any number of child profiles. The local child name is migrated into the first child document only after the parent signs in.

## Firebase setup

1. Create separate Firebase projects for development and production.
2. Enable Email/Password in Authentication. Add Google/Apple later only when their native configuration is ready.
3. Create a Firestore database in the region closest to the main audience.
4. Install the Firebase CLI and FlutterFire CLI, then sign in:

   ```bash
   firebase login
   dart pub global activate flutterfire_cli
   ```

5. Copy `.firebaserc.example` to `.firebaserc`, replace the project ID, and run:

   ```bash
   flutterfire configure
   firebase deploy --only firestore:rules,firestore:indexes
   ```

6. Add `firebase_core`, `firebase_auth`, and `cloud_firestore` when wiring the account UI. Do not commit service-account keys or purchase-provider secrets.

The checked-in rules deliberately reject all unknown collections. Parent-owned profile/progress writes are validated; entitlement writes are denied to clients.

## Cloudflare setup

From `cloudflare/content-worker`:

```bash
npm install
npx wrangler login
npx wrangler r2 bucket create gembala-kecil-content
npx wrangler secret put ADMIN_TOKEN
npm run deploy
```

Change `ALLOWED_ORIGINS` in `wrangler.jsonc` to include the production web origin before deployment. Use a long random `ADMIN_TOKEN`; it belongs only in the local backoffice/server environment and Cloudflare secret storage, never in Flutter.

Upload runtime assets using keys without the local `assets/content/` prefix. Upload the transformed cloud catalog as `catalog.json`; its asset fields should point to `/v1/assets/<key>` or absolute Worker/custom-domain URLs.

Public endpoints:

- `GET /health`
- `GET /v1/catalog`
- `GET|HEAD /v1/assets/<key>` (supports byte ranges for narration seeking)

Admin endpoints require `Authorization: Bearer <ADMIN_TOKEN>`:

- `PUT /v1/admin/catalog`
- `PUT /v1/admin/assets/<key>`
- `DELETE /v1/admin/assets/<key>`

## Activation order

1. Provision Firebase projects and deploy Firestore rules.
2. Generate `lib/firebase_options.dart` with FlutterFire.
3. Wire the existing optional parent-account screen to Firebase Auth and migrate the local child profile after sign-in.
4. Provision R2 and deploy the Worker.
5. Add remote-first catalog loading with bundled local fallback.
6. Update the backoffice to publish immutable revisioned assets, then publish `catalog.json` last.
7. Connect verified App Store/Play purchase webhooks to trusted entitlement writes.

Never grant premium based only on a value written by the Flutter client.
