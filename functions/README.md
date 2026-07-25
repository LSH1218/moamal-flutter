# Firebase STT proxy

Flutter sends authenticated M4A bytes to `transcribeAudio`. The function keeps
`OPENAI_API_KEY` in Firebase Secret Manager and forwards the audio to OpenAI's
transcription endpoint. Audio and transcript contents are not written to logs,
Firestore, or Cloud Storage by this function.

## One-time setup

The Firebase project must be on the Blaze plan to deploy Functions and use the
required Google Cloud services.

```powershell
firebase login
firebase use moamal-1e601
firebase functions:secrets:set OPENAI_API_KEY
```

Paste the OpenAI API key only into the interactive secret prompt. Never put it
in this repository, a Dart define, shell history, or chat message.

## Install, verify, and deploy

```powershell
cd functions
npm install
npm run check
cd ..
firebase deploy --only functions:transcribeAudio
```

The Flutter production default endpoint is:

```text
https://asia-northeast3-moamal-1e601.cloudfunctions.net/transcribeAudio
```

For an emulator or a different Firebase environment, pass only the non-secret
URL:

```powershell
flutter run --dart-define=STT_PROXY_URL=http://10.0.2.2:5001/moamal-1e601/asia-northeast3/transcribeAudio
```

## Contract and controls

- Method: `POST`
- Authorization: Firebase ID token as `Bearer <token>`
- Content-Type: `audio/mp4`, `audio/m4a`, or `audio/x-m4a`
- Body: raw audio, maximum 10 MiB
- Response: `{"text":"..."}`
- Limit: 10 requests per Firebase UID per minute
- Function scaling cap: 10 instances
- OpenAI model: `gpt-4o-mini-transcribe`

The rate-limit documents contain only UID-derived keys, counts, and timestamps.
Configure a Firestore TTL policy on `sttRateLimits.expiresAt` so they are
deleted automatically.

## Deployment follow-up

1. Enable Firebase App Check for Android and iOS, then enforce App Check in the
   function after verified clients are shipping.
2. Configure budget alerts and inspect function/OpenAI usage.
3. Use separate Firebase projects and separate OpenAI secrets for development,
   staging, and production.
4. Add an explicit classroom notice that audio is sent to an external STT
   provider and is processed transiently.
