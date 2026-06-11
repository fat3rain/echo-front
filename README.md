[🇬🇧 English](#echo--real-time-voice-chat-application) · [🇷🇺 Русский](#echo--приложение-для-голосового-чата-в-реальном-времени)
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

# Echo — Приложение для голосового чата в реальном времени

> Flutter-приложение для голосового общения в комнатах, построенное на WebRTC и SFU-архитектуре.

**Стек:** Flutter · Dart · WebRTC · Go · Yandex Cloud  
**Бэкенд:** [echo-back](https://github.com/fat3rain/echo-back) — сигнальный сервер и SFU на Go

---

## О проекте

Echo позволяет создавать голосовые комнаты и подключаться к ним для общения в реальном времени. Приложение берёт на себя обнаружение участников, сигнализацию и маршрутизацию медиапотоков через выделенный бэкенд — нагрузка на клиент остаётся низкой вне зависимости от числа участников в комнате.

Проект реализован полностью с нуля: Flutter-фронтенд, Go-бэкенд задеплоен на Linux-виртуалку в Yandex Cloud, деплой выполняется вручную через SSH и `git pull`.

---

## Архитектура

### Почему SFU, а не mesh?

В **mesh-топологии** каждый участник отправляет аудиопоток напрямую всем остальным. При N пользователях в комнате каждый клиент поддерживает N−1 исходящих и N−1 входящих соединений — нагрузка растёт квадратично. На мобильных устройствах это быстро становится ограничением.

**SFU (Selective Forwarding Unit)** централизует маршрутизацию медиапотоков: каждый клиент отправляет один поток на сервер, который пересылает его остальным участникам. Нагрузка на клиент остаётся постоянной независимо от размера комнаты.

```
Mesh (3 участника):      SFU (3 участника):

 A ←→ B                    A → [SFU] → B
 A ←→ C                    B → [SFU] → A, C
 B ←→ C                    C → [SFU] → A, B
 6 потоков                 3 потока (на стороне клиента)
```

Такой подход позволяет серверу теоретически поддерживать комнаты с 1000+ одновременными участниками — ограничение переносится на пропускную способность сервера, а не клиента.

### Компонентная схема

```
┌─────────────────────────────────────────┐
│            Flutter-клиент               │
│                                         │
│  ┌──────────┐      ┌─────────────────┐  │
│  │    UI    │◄────►│  WebRTC Engine  │  │
│  │(комнаты, │      │ (захват звука,  │  │
│  │ участн.) │      │  peer-треки)    │  │
│  └──────────┘      └────────┬────────┘  │
│                             │           │
└─────────────────────────────┼───────────┘
                              │ WebRTC (ICE/DTLS/SRTP)
                              ▼
┌─────────────────────────────────────────┐
│         Go-бэкенд (Yandex Cloud)        │
│                                         │
│  ┌─────────────┐    ┌─────────────────┐ │
│  │ Сигнализация│    │  SFU / медиа-   │ │
│  │ (WebSocket) │    │  маршрутизатор  │ │
│  └─────────────┘    └─────────────────┘ │
└─────────────────────────────────────────┘
```

### Поток сигнализации

```
Клиент A                  Сервер                  Клиент B
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
   │════════════ SRTP аудиопоток через SFU ════════════│
```

---

## Технологический стек

| Слой | Технология |
|---|---|
| Мобильный клиент | Flutter 3.x / Dart |
| Реальное время | WebRTC (`flutter_webrtc`) |
| Язык бэкенда | Go |
| Транспорт | WebSocket (сигнализация), SRTP (медиа) |
| Хостинг | Yandex Compute Cloud (Ubuntu VM) |
| Деплой | SSH + git clone/pull |

---

## Запуск

### Требования

- Flutter SDK ≥ 3.0
- Запущенный экземпляр [echo-back](https://github.com/fat3rain/echo-back)

### Локальный запуск

```bash
git clone https://github.com/fat3rain/echo-front.git
cd echo-front
flutter pub get
```

Укажи адрес бэкенда в `lib/services/signaling.dart`:

```dart
const String serverUrl = 'ws://YOUR_SERVER_IP:PORT';
```

Запусти:

```bash
flutter run
```

---

## Бэкенд и деплой

Бэкенд ([echo-back](https://github.com/fat3rain/echo-back)) — Go-приложение, выступающее одновременно сигнальным сервером и SFU.

**Хостинг:** Yandex Compute Cloud — Ubuntu VM  
**Процесс деплоя:**

```bash
# Первичная установка
git clone https://github.com/fat3rain/echo-back.git
cd echo-back
# настройка переменных окружения
go run main.go

# Обновление
git pull origin main
# перезапуск сервиса
```

---

## Ключевые архитектурные решения

| Решение | Обоснование |
|---|---|
| SFU вместо mesh | Нагрузка на мобильный клиент остаётся O(1), а не O(N); возможно масштабирование на большие комнаты |
| Go для бэкенда | Низкое потребление памяти, нативные горутины для параллельной обработки WebSocket-соединений, хорошая поддержка WebRTC |
| WebSocket для сигнализации | Необходим постоянный двунаправленный канал для координации peer-соединений в реальном времени |
| Flutter | Один кодовой базы для iOS и Android; `flutter_webrtc` предоставляет нативные WebRTC-биндинги |

---

## Автор

**Бедарев Даниил** — [@fat3rain](https://github.com/fat3rain)  
Студент 3 курса, Прикладная информатика, ГУУ Москва  
Telegram: [@fattrain](https://t.me/fattrain)

