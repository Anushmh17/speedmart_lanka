/* Minimal Node.js example that accepts an HTTP POST to send FCM messages.

Setup:
1. Create a Firebase project and generate a service account JSON.
2. Place the JSON at ./serviceAccountKey.json (DO NOT COMMIT).
3. Run `npm install` and then `node index.js`.

POST /send
  body: {
    "token": "<fcm_token>",
    "title": "New Proposal",
    "body": "You have a new proposal",
    "data": { "route": "/customer/proposals/PROPOSAL_ID", "relatedId": "PROPOSAL_ID" }
  }
*/

const express = require('express');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');

// Load service account (ensure you created this file)
try {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
} catch (e) {
  console.error('Missing serviceAccountKey.json. Follow README in tools/fcm_server_example.');
  process.exit(1);
}

const app = express();
app.use(bodyParser.json());

app.post('/send', async (req, res) => {
  const { token, title, body, data } = req.body;
  if (!token) return res.status(400).json({ error: 'token is required' });

  const message = {
    token,
    notification: {
      title: title || 'Notification',
      body: body || '',
    },
    data: data || {},
  };

  try {
    const r = await admin.messaging().send(message);
    return res.json({ success: true, result: r });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: e.message });
  }
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log('FCM example server running on port', PORT));
