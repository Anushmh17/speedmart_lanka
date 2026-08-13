// create_test_user.js
// Creates (or fetches) a test user in the Auth emulator and returns an ID token
const admin = require('firebase-admin');
// Node 18+ provides global `fetch` — no external dependency required.

process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
process.env.FIREBASE_AUTH_EMULATOR_URL = process.env.FIREBASE_AUTH_EMULATOR_URL || `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`;

admin.initializeApp({projectId: 'speedmart-lanka'});

async function main(){
  const uid = 'loadtest-user-1';
  const email = 'loadtest+1@example.com';
  const phone = '+94770000001';
  try{
    let user;
    try{
      user = await admin.auth().getUser(uid);
    }catch(e){
      user = await admin.auth().createUser({uid, email, phoneNumber: phone, password: 'password123'});
    }

    const customToken = await admin.auth().createCustomToken(uid);

    // Exchange custom token for ID token using emulator REST endpoint
    const url = `http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=any`;
    const res = await fetch(url, {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({token: customToken, returnSecureToken: true})
    });
    const body = await res.json();
    if(!body.idToken){
      console.error('Failed to exchange custom token:', body);
      process.exit(2);
    }
    console.log(JSON.stringify({idToken: body.idToken, uid, email, phone}));
  }catch(err){
    console.error(err);
    process.exit(1);
  }
}

main();
