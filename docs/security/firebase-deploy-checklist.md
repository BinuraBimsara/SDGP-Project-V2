# Firebase Security Deploy Checklist

1. Deploy rules and functions together:
   - `firebase deploy --only firestore:rules,storage,functions`
2. Verify callable functions are in `asia-south1`.
3. Validate complaint creation/update paths as citizen and official users.
4. Validate App Check tokens from Android, iOS, and Web.
5. Confirm denied cases:
   - client counter tampering
   - role self-promotion
   - anonymous writes
   - public storage access
6. Review Firebase logs for auth failures and rate anomalies.
