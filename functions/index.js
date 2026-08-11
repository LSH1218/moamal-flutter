// runtime: nodejs22
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {logger} = require("firebase-functions");

const KAKAO_PROFILE_URL = "https://kapi.kakao.com/v2/user/me";
const NAVER_PROFILE_URL = "https://openapi.naver.com/v1/nid/me";

initializeApp();

const openAiApiKey = defineSecret("OPENAI_API_KEY");
const geminiApiKey = defineSecret("GEMINI_API_KEY");

const allowedGeminiModels = new Set([
  "gemini-2.5-flash",
  "gemini-2.0-flash",
  "gemini-2.0-flash-lite",
]);
const maxAudioBytes = 10 * 1024 * 1024;
const allowedContentTypes = new Set([
  "audio/mp4",
  "audio/m4a",
  "audio/x-m4a",
]);

exports.transcribeAudio = onRequest(
    {
      region: "asia-northeast3",
      secrets: [openAiApiKey],
      timeoutSeconds: 60,
      memory: "256MiB",
      maxInstances: 10,
    },
    async (request, response) => {
      if (request.method !== "POST") {
        response.set("Allow", "POST").status(405).json({error: "method_not_allowed"});
        return;
      }

      try {
        const uid = await authenticatedUid(request);
        const audio = request.rawBody;
        const contentType = normalizedContentType(request.get("content-type"));

        if (!allowedContentTypes.has(contentType)) {
          response.status(415).json({error: "unsupported_audio_type"});
          return;
        }
        if (!audio || audio.length === 0 || audio.length > maxAudioBytes) {
          response.status(413).json({error: "invalid_audio_size"});
          return;
        }

        await enforceRateLimit(uid);

        const form = new FormData();
        form.append("model", "whisper-1");
        form.append("language", "ko");
        const whisperPrompt = typeof request.query.prompt === "string" ? request.query.prompt.slice(0, 500) : "";
        if (whisperPrompt) form.append("prompt", whisperPrompt);
        form.append("file", new Blob([audio], {type: contentType}), "stt.m4a");

        const upstream = await fetch("https://api.openai.com/v1/audio/transcriptions", {
          method: "POST",
          headers: {Authorization: `Bearer ${openAiApiKey.value()}`},
          body: form,
        });

        if (!upstream.ok) {
          logger.error("OpenAI transcription failed", {
            status: upstream.status,
            uid,
          });
          response.status(502).json({error: "transcription_failed"});
          return;
        }

        const result = await upstream.json();
        const text = typeof result.text === "string" ? result.text.trim() : "";
        if (!text) {
          response.status(502).json({error: "empty_transcription"});
          return;
        }

        response.set("Cache-Control", "no-store").status(200).json({text});
      } catch (error) {
        if (error && error.code === "rate_limited") {
          response.status(429).json({error: "rate_limited"});
          return;
        }
        if (error && error.code === "unauthenticated") {
          response.status(401).json({error: "unauthenticated"});
          return;
        }
        logger.error("STT proxy request failed", error);
        response.status(500).json({error: "internal"});
      }
    },
);

exports.geminiProxy = onRequest(
    {
      region: "asia-northeast3",
      secrets: [geminiApiKey],
      timeoutSeconds: 60,
      memory: "256MiB",
      maxInstances: 10,
    },
    async (request, response) => {
      if (request.method !== "POST") {
        response.set("Allow", "POST").status(405).json({error: "method_not_allowed"});
        return;
      }

      try {
        const uid = await authenticatedUid(request);
        const {model, ...geminiBody} = request.body ?? {};

        if (!model || !allowedGeminiModels.has(model)) {
          response.status(400).json({error: "invalid_model"});
          return;
        }

        await enforceGeminiRateLimit(uid);

        const upstream = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiApiKey.value()}`,
            {
              method: "POST",
              headers: {"Content-Type": "application/json"},
              body: JSON.stringify(geminiBody),
            },
        );

        if (!upstream.ok) {
          logger.error("Gemini request failed", {status: upstream.status, uid});
          response.status(502).json({error: "gemini_failed"});
          return;
        }

        const result = await upstream.json();
        const text = result?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (typeof text !== "string" || !text) {
          response.status(502).json({error: "empty_response"});
          return;
        }

        response.set("Cache-Control", "no-store").status(200).json({text});
      } catch (error) {
        if (error && error.code === "rate_limited") {
          response.status(429).json({error: "rate_limited"});
          return;
        }
        if (error && error.code === "unauthenticated") {
          response.status(401).json({error: "unauthenticated"});
          return;
        }
        logger.error("Gemini proxy request failed", error);
        response.status(500).json({error: "internal"});
      }
    },
);

async function authenticatedUid(request) {
  const authorization = request.get("authorization") || "";
  if (!authorization.startsWith("Bearer ")) {
    throw codedError("unauthenticated");
  }
  try {
    const decoded = await getAuth().verifyIdToken(authorization.slice(7));
    return decoded.uid;
  } catch (_) {
    throw codedError("unauthenticated");
  }
}

async function enforceRateLimit(uid) {
  const bucket = Math.floor(Date.now() / 60000);
  const ref = getFirestore().doc(`sttRateLimits/${uid}_${bucket}`);
  await getFirestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const count = snapshot.exists ? snapshot.data().count || 0 : 0;
    if (count >= 10) throw codedError("rate_limited");
    transaction.set(ref, {
      count: count + 1,
      expiresAt: new Date(Date.now() + 2 * 60 * 60 * 1000),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

async function enforceGeminiRateLimit(uid) {
  const bucket = Math.floor(Date.now() / 60000);
  const ref = getFirestore().doc(`geminiRateLimits/${uid}_${bucket}`);
  await getFirestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const count = snapshot.exists ? snapshot.data().count || 0 : 0;
    if (count >= 20) throw codedError("rate_limited");
    transaction.set(ref, {
      count: count + 1,
      expiresAt: new Date(Date.now() + 2 * 60 * 60 * 1000),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

function normalizedContentType(value) {
  return String(value || "").split(";", 1)[0].trim().toLowerCase();
}

function codedError(code) {
  const error = new Error(code);
  error.code = code;
  return error;
}

// ── 카카오 소셜 로그인 ────────────────────────────────────────────────────────

exports.kakaoVerify = onRequest(
    {
      region: "asia-northeast3",
      timeoutSeconds: 30,
      memory: "256MiB",
      maxInstances: 10,
    },
    async (request, response) => {
      if (request.method !== "POST") {
        response.set("Allow", "POST").status(405).json({error: "method_not_allowed"});
        return;
      }

      const accessToken = request.body?.accessToken;
      if (!accessToken || typeof accessToken !== "string") {
        response.status(400).json({error: "missing_access_token"});
        return;
      }

      try {
        const upstream = await fetch(KAKAO_PROFILE_URL, {
          headers: {Authorization: `Bearer ${accessToken}`},
        });

        if (!upstream.ok) {
          logger.warn("Kakao token verification failed", {status: upstream.status});
          response.status(401).json({error: "invalid_kakao_token"});
          return;
        }

        const profile = await upstream.json();
        const kakaoId = profile.id?.toString();
        if (!kakaoId) {
          response.status(502).json({error: "kakao_id_missing"});
          return;
        }

        const uid = `kakao:${kakaoId}`;
        const customToken = await getAuth().createCustomToken(uid, {provider: "kakao"});
        response.set("Cache-Control", "no-store").status(200).json({customToken});
      } catch (error) {
        logger.error("kakaoVerify failed", error);
        response.status(500).json({error: "internal"});
      }
    },
);

// ── 네이버 소셜 로그인 ────────────────────────────────────────────────────────

exports.naverVerify = onRequest(
    {
      region: "asia-northeast3",
      timeoutSeconds: 30,
      memory: "256MiB",
      maxInstances: 10,
    },
    async (request, response) => {
      if (request.method !== "POST") {
        response.set("Allow", "POST").status(405).json({error: "method_not_allowed"});
        return;
      }

      const accessToken = request.body?.accessToken;
      if (!accessToken || typeof accessToken !== "string") {
        response.status(400).json({error: "missing_access_token"});
        return;
      }

      try {
        const upstream = await fetch(NAVER_PROFILE_URL, {
          headers: {Authorization: `Bearer ${accessToken}`},
        });

        if (!upstream.ok) {
          logger.warn("Naver token verification failed", {status: upstream.status});
          response.status(401).json({error: "invalid_naver_token"});
          return;
        }

        const profile = await upstream.json();
        const naverId = profile.response?.id?.toString();
        if (!naverId) {
          response.status(502).json({error: "naver_id_missing"});
          return;
        }

        const uid = `naver:${naverId}`;
        const customToken = await getAuth().createCustomToken(uid, {provider: "naver"});
        response.set("Cache-Control", "no-store").status(200).json({customToken});
      } catch (error) {
        logger.error("naverVerify failed", error);
        response.status(500).json({error: "internal"});
      }
    },
);
