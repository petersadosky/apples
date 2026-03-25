const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const OpenAI = require("openai");

initializeApp();

exports.generateImage = onCall(
  {
    secrets: ["OPENAI_API_KEY"],
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (request) => {
    // Auth check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }

    const { sessionId, roundId, playerId, prompt } = request.data;

    // Input validation
    if (!sessionId || !roundId || !playerId || !prompt) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    // Verify caller identity
    if (request.auth.uid !== playerId) {
      throw new HttpsError(
        "permission-denied",
        "Can only generate images for yourself"
      );
    }

    const db = getFirestore();
    const roundRef = db
      .collection("sessions")
      .doc(sessionId)
      .collection("rounds")
      .doc(roundId);

    // Verify submission exists
    const roundDoc = await roundRef.get();
    if (!roundDoc.exists) {
      throw new HttpsError("not-found", "Round not found");
    }

    const roundData = roundDoc.data();
    const submission = roundData.submissions?.[playerId];

    if (!submission) {
      throw new HttpsError("not-found", "Submission not found");
    }

    // Skip if already generated
    if (submission.generatedImageURL) {
      return { imageURL: submission.generatedImageURL };
    }

    // Call DALL-E 3
    const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

    let dallEUrl;
    try {
      const response = await openai.images.generate({
        model: "dall-e-3",
        prompt: prompt,
        n: 1,
        size: "1024x1024",
        quality: "standard",
      });
      dallEUrl = response.data[0].url;
    } catch (err) {
      console.error("DALL-E API error:", err.message);
      throw new HttpsError("internal", "Image generation failed");
    }

    // Download image and upload to Firebase Storage for a permanent URL
    let permanentUrl;
    try {
      const imageResponse = await fetch(dallEUrl);
      const buffer = Buffer.from(await imageResponse.arrayBuffer());

      const bucket = getStorage().bucket();
      const filePath = `generated/${sessionId}/${roundId}/${playerId}.png`;
      const file = bucket.file(filePath);

      await file.save(buffer, {
        contentType: "image/png",
        public: true,
      });

      permanentUrl = `https://storage.googleapis.com/${bucket.name}/${filePath}`;
    } catch (err) {
      console.error("Storage upload error:", err.message);
      // Fall back to temporary DALL-E URL if storage fails
      permanentUrl = dallEUrl;
    }

    // Write URL to Firestore
    await roundRef.update({
      [`submissions.${playerId}.generatedImageURL`]: permanentUrl,
    });

    return { imageURL: permanentUrl };
  }
);
