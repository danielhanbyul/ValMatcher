// ----------------------------------------------
// index.js — Cloud Functions v2 (Node 18+)
// ----------------------------------------------

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const {GoogleAuth} = require("google-auth-library");

admin.initializeApp();

/**
 * Triggered when a new document is created in `matches/{matchId}`.
 * Sends FCM notifications to matched users.
 */
exports.sendMatchNotification = onDocumentCreated(
    {
      document: "matches/{matchId}",
    // optional: region: 'us-central1',
    // optional: runtime: 'nodejs18',
    },
    async (event) => {
      const snap = event.data;
      if (!snap) {
        console.log("No data in Firestore event");
        return null;
      }

      // Extract data
      const matchData = snap.data();

      const user1Id = matchData.user1;
      const user2Id = matchData.user2;

      // Fetch user details
      const [user1Doc, user2Doc] = await Promise.all([
        admin.firestore().collection("users").doc(user1Id).get(),
        admin.firestore().collection("users").doc(user2Id).get(),
      ]);

      if (!user1Doc.exists || !user2Doc.exists) {
        console.log("One of the user documents does not exist.");
        return null;
      }

      const user1Data = user1Doc.data();
      const user2Data = user2Doc.data();

      const user1FcmToken = user1Data.fcmToken;
      const user2FcmToken = user2Data.fcmToken;

      const user1Name = user1Data.name || "Someone";
      const user2Name = user2Data.name || "Someone";

      // Create notification payloads
      const payload1 = {
        notification: {
          title: "It's a Match!",
          body: `You matched with ${user2Name}!`,
          sound: "default",
        },
      };

      const payload2 = {
        notification: {
          title: "It's a Match!",
          body: `You matched with ${user1Name}!`,
          sound: "default",
        },
      };

      // Send notifications
      const promises = [];

      if (user1FcmToken) {
        promises.push(admin.messaging().sendToDevice(user1FcmToken, payload1));
      } else {
        console.log(`No FCM token for user ${user1Id}`);
      }

      if (user2FcmToken) {
        promises.push(admin.messaging().sendToDevice(user2FcmToken, payload2));
      } else {
        console.log(`No FCM token for user ${user2Id}`);
      }

      return Promise.all(promises);
    },
);

/**
 * Returns an FCM access token via HTTPS request.
 */
async function getAccessToken() {
  const auth = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const client = await auth.getClient();
  const accessTokenResponse = await client.getAccessToken();
  return accessTokenResponse.token;
}


exports.getAccessToken = onRequest(async (req, res) => {
  try {
    const token = await getAccessToken();
    res.status(200).json({accessToken: token});
  } catch (error) {
    console.error("Error fetching access token:", error);
    res.status(500).json({error: "Unable to fetch access token"});
  }
});

