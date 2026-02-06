# iOS Universal Links – Next Steps (outside this project)

This app already has universal link handling in place: route `/log/:logId`, `app_links` on iOS, and Associated Domains for both `notathletes.com` and `www.notathletes.com`. Deep links are only handled when the user is authenticated.

What **cannot** be done in this repo and must be done elsewhere:

---

## 1. Host the Apple App Site Association (AASA) file

Serve the **apple-app-site-association** file from your domain (e.g. the Next.js app for notathletes.com).

- **URLs:** The same file must be served at **both**:
  - `https://notathletes.com/.well-known/apple-app-site-association`
  - `https://www.notathletes.com/.well-known/apple-app-site-association`  
  (no file extension; optional `Content-Type: application/json`.)  
  Links with or without `www` only open the app if that host has a valid AASA.

**Example content** (replace `<TEAM_ID>`, `<BUNDLE_ID_CLIENT>`, `<BUNDLE_ID_COACH>` with your values):

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appIDs": [
          "<TEAM_ID>.<BUNDLE_ID_CLIENT>",
          "<TEAM_ID>.<BUNDLE_ID_COACH>"
        ],
        "paths": ["/log/*"],
        "components": [
          {
            "/": "/log/*"
          }
        ]
      }
    ]
  }
}
```

- **appIDs:** `<Team ID>.<Bundle ID>` from [Apple Developer](https://developer.apple.com/account) (Membership) and Xcode (Bundle Identifier). One entry per app (client/coach) that should open `/log/*` links.
- **paths:** `["/log/*"]` restricts links to the session screen; use `["*"]` only if you want all paths to open the app.

Host this at both domains (notathletes.com and www.notathletes.com) so that both `https://notathletes.com/log/...` and `https://www.notathletes.com/log/...` open the app. Apple’s CDN may cache AASA for a while after first fetch.

---

## 2. Backend: FCM payload so notification tap opens the session

When sending push notifications for “coach feedback” or “session logged”, the backend must include the FCM **data** payload so that when the user taps the notification, the app opens the right session. The app expects `type: "view_log"` and `logId: "<routine_log_uuid>"`.

Request bodies and full FCM spec are in **`docs/FCM_PAYLOAD_SPEC.md`** (handover for backend).

---

## 3. Testing

- Install the app, then open (from Notes or Safari):  
  `https://notathletes.com/log/<log-id>` or `https://www.notathletes.com/log/<log-id>`  
  The app should open to that routine log when the user is authenticated.
- Simulator:  
  `xcrun simctl openurl booted "https://www.notathletes.com/log/<log-id>"`

---

## Reference

- [Flutter: Set up universal links for iOS](https://docs.flutter.dev/cookbook/navigation/set-up-universal-links)
- [Apple: Supporting Universal Links](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)
