/**
 * Import function triggers from their respective submodules.
 *
 * Here we import the necessary modules to create Cloud Functions
 * and initialize the Firebase Admin SDK to interact with Firestore.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

/**
 * Cloud Function to send a notification when a new message is created.
 * This function triggers whenever a new document is added to the
 * "messages" collection in Firestore.
 */
exports.sendNewMessageNotification = functions.firestore
    .document("messages/{messageId}")
    .onCreate(async (snapshot, context) => {
    // Get the message data from the snapshot
      const messageData = snapshot.data();
      const senderId = messageData.senderId;
      const recipientToken = messageData.recipientFcmToken;

      // Default sender's name
      let senderName = "Someone";

      try {
      // Fetch the sender's name from the Firestore "users" collection
        const senderDoc = await admin.firestore()
            .collection("users")
            .doc(senderId)
            .get();

        if (senderDoc.exists) {
        // Set the sender's name to the user's name in Firestore
          senderName = senderDoc.data().name || "Someone";
        }
      } catch (error) {
        console.error("Error fetching sender's name:", error);
      }

      // Define the notification payload
      const payload = {
        notification: {
          title: `New Message from ${senderName}`, // Title of the notification
          body: messageData.text || "You have a new message!", // Message body
          sound: "default", // Notification sound
        },
        data: {
          senderName: senderName, // Sender's name for data processing
          message: messageData.text || "", // The actual message
          type: "chat_message", // Type of notification
        },
      };

      try {
      // Send the notification using the recipient's FCM token
        await admin.messaging().sendToDevice(recipientToken, payload);
        console.log("Notification sent successfully");
      } catch (error) {
        console.error("Error sending notification:", error);
      }
    });


// const {onRequest} = require("firebase-functions/v2/https");
// const logger = require("firebase-functions/logger");

// Example of an HTTP-triggered function
// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
