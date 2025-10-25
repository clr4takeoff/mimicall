const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const axios = require("axios");
const FormData = require("form-data");
const fs = require("fs");
const path = require("path");
const cors = require("cors");

// ✅ 비밀키 참조 정의
const ELEVEN_API_KEY = defineSecret("ELEVEN_API_KEY");

admin.initializeApp();
const corsHandler = cors({ origin: true });

exports.cloneVoice = onRequest({ secrets: [ELEVEN_API_KEY] }, async (req, res) => {
  corsHandler(req, res, async () => {
    try {
      const apiKey = ELEVEN_API_KEY.value();
      if (!apiKey) return res.status(500).send("Missing ELEVEN_API_KEY");

      const body = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
      const { name, url } = body || {};
      if (!url || !name) return res.status(400).send("Missing name or url");

      logger.info(`🎤 클로닝 요청: ${name}, 파일: ${url}`);

      // 🔹 1️⃣ 파일 다운로드
      const audioRes = await axios.get(url, { responseType: "arraybuffer" });
      const buffer = Buffer.from(audioRes.data);

      // 🔹 2️⃣ 임시 파일 저장
      const tempPath = path.join("/tmp", `${name}.m4a`);
      fs.writeFileSync(tempPath, buffer);

      // 🔹 3️⃣ FormData 구성
      const formData = new FormData();
      formData.append("name", name);
      formData.append("files", fs.createReadStream(tempPath));

      // 🔹 4️⃣ ElevenLabs API 요청
      const elevenRes = await axios.post(
        "https://api.elevenlabs.io/v1/voices/add",
        formData,
        {
          headers: {
            "xi-api-key": apiKey,
            ...formData.getHeaders(),
          },
          maxBodyLength: Infinity,
        }
      );

      const data = elevenRes.data;
      logger.info("🧩 ElevenLabs response:", JSON.stringify(data, null, 2));

      const voiceId = data.voice_id;
      await admin
        .database()
        .ref(`preference/${name}/character_settings`)
        .update({ voiceId });

      logger.info(`✅ Voice cloned successfully: ${voiceId}`);
      return res.status(200).json({ success: true, voiceId });
    } catch (e) {
      logger.error("🔥 cloneVoice error:", e?.response?.data || e.message);
      return res.status(500).send({ error: e?.response?.data || e.message });
    }
  });
});
