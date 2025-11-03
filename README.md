# Mimicall ☎️

**Mimicall** is an AI-assisted language therapy prototype that helps children practice speech by talking with AI-generated characters.  
Parents can set conversation topics, target sentences, and character voices, while the system generates real-time interactive conversations and reports.

---

## Overview

- AI conversation system for child speech practice
- Voice cloning for personalized character voices
- Automatic STT (speech-to-text) and TTS (text-to-speech)
- Conversation report generation and progress tracking
- Cloud-based backend with Firebase and serverless functions

---

## Tech Stack

| Layer | Technology |
|--------|-------------|
| **Frontend** | Flutter |
| **Backend** | Node.js (Firebase Functions) |
| **Database / Storage** | Firebase Realtime Database, Firebase Storage |
| **AI / APIs** | OpenAI (GPT-4o, Whisper, DALL·E 3), ElevenLabs (TTS, Voice Cloning), GoEnhance (Image-to-Video) |
| **Version Control** | GitHub |

---

## System Architecture
<img width="1000" height="600" alt="도식" src="https://github.com/user-attachments/assets/60829167-cae5-48fa-98ec-8e2ac61c2ba4" />
*Figure 1. Mimicall service architecture*

---

## App Structure

**Screens**
- `name_landing_screen.dart` – user entry / name input
- `main_screen.dart` – main dashboard
- `incoming_call_screen.dart` – incoming call screen
- `in_call_screen.dart` – live call (character conversation)
- `report_list_screen.dart`, `report_screen.dart` – conversation report list and details

**Widgets**
- Modular UI components for reuse
- Examples: `chat_bubble.dart`, `app_header.dart`, `character_settings.dart`, `report_summary_box.dart`

---

## Backend Overview

- **Realtime Database:** user data and conversation storage
- **Cloud Functions:** voice cloning and AI response generation
- **Storage:** user-uploaded voice files for character cloning

---

## APIs

| API | Purpose |
|------|----------|
| **OpenAI** | GPT-4o for dialogue, Whisper for STT, DALL·E 3 for visual summaries |
| **ElevenLabs** | Voice cloning and text-to-speech |
| **GoEnhance** | Image-to-video animation for character motion |
