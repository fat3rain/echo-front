[README.md](https://github.com/user-attachments/files/28856138/README.md)
# Echo — Real-Time Voice Chat Application

> A Flutter-based voice chat application with room-based communication, built on WebRTC and an SFU architecture.

**Stack:** Flutter · Dart · WebRTC · Go · Yandex Cloud  
**Companion repo:** [echo-back](https://github.com/fat3rain/echo-back) — Go signaling server & SFU

---

## Overview

Echo allows users to create and join voice rooms for real-time audio communication. The application handles peer discovery, signaling, and media routing through a dedicated backend, keeping client-side resource usage low even as the number of participants grows.

The project was built end-to-end: Flutter frontend, Go backend deployed on a Linux virtual machine in Yandex Cloud, with manual deployment via SSH and `git pull`.

---

## Architecture

### Why SFU over Mesh?

In a **mesh topology**, every participant sends their audio stream directly to every other participant. With N users in a room, each client maintains N−1 outgoing and N−1 incoming connections — resource usage scales quadratically. On mobile devices this becomes a hard constraint quickly.

An **SFU (Selective Forwarding Unit)** centralises media routing: each client sends one stream to the server, which forwards it selectively to other participants. Client-side load stays constant regardless of room size.

```
Mesh (3 users):          SFU (3 users):

 A ←→ B                    A → [SFU] → B
 A ←→ C                    B → [SFU] → A, C
 B ←→ C                    C → [SFU] → A, B
 6 streams total           3 streams total (client-side)
```

This design allows the server to theoretically support rooms with 1000+ concurrent users, limited by server bandwidth rather than client capability.

### Component Diagram

```
┌─────────────────────────────────────────┐
│              Flutter Client             │
│                                         │
│  ┌──────────┐      ┌─────────────────┐  │
│  │    UI    │◄────►│  WebRTC Engine  │  │
│  │ (Rooms,  │      │ (audio capture, │  │
│  │  Users)  │      │  peer tracks)   │  │
│  └──────────┘      └────────┬────────┘  │
│                             │           │
└─────────────────────────────┼───────────┘
                              │ WebRTC (ICE/DTLS/SRTP)
                              ▼
┌─────────────────────────────────────────┐
│           Go Backend (Yandex Cloud)     │
│                                         │
│  ┌─────────────┐    ┌─────────────────┐ │
│  │  Signaling  │    │  SFU / Media    │ │
│  │  (WebSocket)│    │  Router         │ │
│  └─────────────┘    └─────────────────┘ │
└─────────────────────────────────────────┘
```

### Signaling Flow

```
Client A                  Server                  Client B
   │                         │                         │
   │── WebSocket connect ───►│                         │
   │── join_room(roomId) ───►│                         │
   │                         │◄── WebSocket connect ───│
   │                         │◄── join_room(roomId) ───│
   │                         │                         │
   │◄── peer_joined ─────────│                         │
   │── SDP offer ───────────►│──── SDP offer ─────────►│
   │◄────────────────────────│◄─── SDP answer ─────────│
   │── ICE candidates ──────►│──── ICE candidates ────►│
   │                         │                         │
   │════════ SRTP audio stream via SFU ════════════════│
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile client | Flutter 3.x / Dart |
| Real-time communication | WebRTC (`flutter_webrtc`) |
| Backend language | Go |
| Transport | WebSocket (signaling), SRTP (media) |
| Hosting | Yandex Compute Cloud (Ubuntu VM) |
| Deployment | SSH + git clone/pull |

---

## Repository Structure

```
echo-front/
├── lib/
│   ├── main.dart              # App entry point
│   ├── screens/               # UI screens (rooms list, room view)
│   ├── services/
│   │   ├── signaling.dart     # WebSocket signaling logic
│   │   └── webrtc_service.dart# Peer connection management
│   └── models/                # Room, User data models
├── pubspec.yaml
└── README.md
```

---

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.0
- A running instance of [echo-back](https://github.com/fat3rain/echo-back)

### Run locally

```bash
git clone https://github.com/fat3rain/echo-front.git
cd echo-front
flutter pub get
```

Set the backend URL in `lib/services/signaling.dart`:

```dart
const String serverUrl = 'ws://YOUR_SERVER_IP:PORT';
```

Then run:

```bash
flutter run
```

---

## Backend & Deployment

The backend ([echo-back](https://github.com/fat3rain/echo-back)) is a Go application acting as both signaling server and SFU.

**Deployed on:** Yandex Compute Cloud — Ubuntu VM  
**Deployment process:**

```bash
# Initial setup
git clone https://github.com/fat3rain/echo-back.git
cd echo-back
# configure environment variables
go run main.go

# Subsequent updates
git pull origin main
# restart service
```

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| SFU over mesh | Keeps mobile client load O(1) instead of O(N); enables scaling to large rooms |
| Go for backend | Low memory footprint, native goroutines for concurrent WebSocket handling, good WebRTC library support |
| WebSocket for signaling | Persistent bidirectional channel needed for real-time peer coordination; REST would require polling |
| Flutter | Single codebase for iOS and Android; `flutter_webrtc` provides native WebRTC bindings |

---

## Author

**Daniil Bedarev** — [@fat3rain](https://github.com/fat3rain)   
Telegram: [@fattrain](https://t.me/fattrain)
