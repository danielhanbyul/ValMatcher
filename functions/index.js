/**
 * Import function triggers from their respective submodules.
 *
 * Here we import the necessary modules to create Cloud Functions
 * and initialize the Firebase Admin SDK to interact with Firestore.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendMatchNotification = functions.firestore
    .document('matches/{matchId}')
    .onCreate(async (snap, context) => {
        const matchData = snap.data();
        const user1Id = matchData.user1;
        const user2Id = matchData.user2;

        // Fetch user details
        const [user1Doc, user2Doc] = await Promise.all([
            admin.firestore().collection('users').doc(user1Id).get(),
            admin.firestore().collection('users').doc(user2Id).get()
        ]);

        if (!user1Doc.exists || !user2Doc.exists) {
            console.log('One of the user documents does not exist.');
            return null;
        }

        const user1Data = user1Doc.data();
        const user2Data = user2Doc.data();

        const user1FcmToken = user1Data.fcmToken;
        const user2FcmToken = user2Data.fcmToken;

        const user1Name = user1Data.name || 'Someone';
        const user2Name = user2Data.name || 'Someone';

        // Create notification payloads
        const payload1 = {
            notification: {
                title: "It's a Match!",
                body: `You matched with ${user2Name}!`,
                sound: 'default'
            }
        };

        const payload2 = {
            notification: {
                title: "It's a Match!",
                body: `You matched with ${user1Name}!`,
                sound: 'default'
            }
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
    });
