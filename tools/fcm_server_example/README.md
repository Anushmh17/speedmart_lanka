FCM Server Example

Minimal Node.js example to send FCM data/notification messages using a service account.

Setup
1. Create a Firebase project and generate a service account JSON.
2. Save the JSON as `tools/fcm_server_example/serviceAccountKey.json` (keep private).
3. Install dependencies:

```bash
cd tools/fcm_server_example
npm install
```

4. Start the server:

```bash
node index.js
```

5. Example request (replace TOKEN):

```bash
curl -X POST http://localhost:8080/send \
  -H "Content-Type: application/json" \
  -d '{"token":"TOKEN","title":"New Request Nearby","body":"A customer near you submitted a request.","data":{"route":"/vendor/requests/REQUEST_ID","relatedId":"REQUEST_ID"}}'
```
