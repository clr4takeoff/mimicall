import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import fetch from "node-fetch";
import FormData from "form-data";
import { initializeApp } from "firebase-admin/app";
import { getDatabase } from "firebase-admin/database";

initializeApp();

// ElevenLabs 음성 클로닝 함수
export const cloneVoice = onRequest(async (req, res) => {
  try {
    const { url, name } = req.body;

    if (!url || !name) {
      res.status(400).send({ error: "url과 name 필드는 필수입니다." });
      return;
    }

    const apiKey = process.env.ELEVENLABS_API_KEY;
    if (!apiKey) {
      throw new Error("ElevenLabs API 키가 설정되지 않았습니다.");
    }

    logger.info(`Voice clone request for ${name}: ${url}`);

    // Firebase Storage에 있는 음성 파일 가져오기
    const voiceResponse = await fetch(url);
    const buffer = await voiceResponse.arrayBuffer();

    // ElevenLabs에 업로드
    const form = new FormData();
    form.append("name", `${name}_voice`);
    form.append("files", Buffer.from(buffer), "voice.mp3");

    const response = await fetch("https://api.elevenlabs.io/v1/voices/add", {
      method: "POST",
      headers: { "xi-api-key": apiKey },
      body: form,
    });

    const data = await response.json();
    if (!data.voice_id) {
      logger.error("ElevenLabs API 오류", data);
      throw new Error(JSON.stringify(data));
    }

    // voice_id를 Firebase Realtime DB에 저장
    const db = getDatabase();
    await db
      .ref(`preference/${name}/character_settings`)
      .update({ voiceId: data.voice_id });

    res.status(200).send({
      success: true,
      voiceId: data.voice_id,
    });
  } catch (err) {
    logger.error("cloneVoice 함수 오류", err);
    res.status(500).send({ error: err.toString() });
  }
});
