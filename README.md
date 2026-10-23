# LifePilot — AI-Powered Work & Productivity

**Less chaos. More progress.**

LifePilot is a native iOS productivity application designed to help professionals organize tasks, manage work documents, and take action through an AI-powered assistant — all from one workspace.

<p align="center">
  <img src="docs/images/lifepilot-overview.png" alt="LifePilot productivity app overview" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS-147EFB?style=flat-square&logo=apple&logoColor=white" alt="iOS">
  <img src="https://img.shields.io/badge/Language-Swift-orange?style=flat-square&logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/UI-SwiftUI-007AFF?style=flat-square" alt="SwiftUI">
  <img src="https://img.shields.io/badge/AI-Document%20Intelligence-7C3AED?style=flat-square" alt="AI">
  <img src="https://img.shields.io/badge/Status-In%20Development-64748B?style=flat-square" alt="In development">
</p>

---

## Overview

Modern work involves juggling tasks, deadlines, documents, and conversations across disconnected tools. LifePilot aims to bring these workflows together in a focused, native iOS experience.

### Core capabilities

- **Task management** — organize work, prioritize tasks, and track progress.
- **Planning** — manage scheduled work and important deadlines.
- **Document intelligence** — organize PDF documents, extract text with OCR, and ask questions about document contents.
- **AI assistant** — interact with an assistant to get help with work and prepare task actions.
- **Action confirmation** — review proposed task changes before confirming or cancelling them.

## App Screens

### 01 — Home & Dashboard

<!-- Replace with a real screenshot captured from the running app. -->
<p align="center">
  <img src="docs/images/home-dashboard.png" alt="LifePilot home dashboard" width="280">
</p>

Your central workspace for getting oriented, reviewing priorities, and accessing the app's key productivity features.

### 02 — Documents

<p align="center">
  <img src="docs/images/documents.png" alt="LifePilot document library" width="280">
</p>

Keep work-related PDFs organized and accessible from a dedicated document library.

### 03 — PDF Intelligence Assistant

<p align="center">
  <img src="docs/images/pdf-assistant.png" alt="LifePilot PDF intelligence assistant" width="280">
</p>

Ask questions about supported documents and retrieve useful information using document text extraction and AI-assisted retrieval.

### 04 — AI Chat & Task Actions

<p align="center">
  <img src="docs/images/ai-chat-actions.png" alt="LifePilot AI chat and task action preview" width="280">
</p>

Use natural-language conversations to prepare supported task operations. Review proposed changes before deciding whether to apply or cancel them.

> The screenshots above use repository image paths as placeholders. Add actual app screenshots at those paths before publishing the README.

---

## Technical Architecture

LifePilot is being developed as a native iOS application, with a modular structure intended to keep its UI, domain logic, persistence, and AI integrations maintainable.

| Layer | Responsibility |
|---|---|
| Presentation | SwiftUI screens and reusable components |
| View models | UI state and application workflows |
| Domain | Task, priority, and document models |
| Persistence | Local task and document metadata storage |
| Document processing | PDFKit and Vision OCR |
| AI integration | Document question answering and assistant workflows |
| Testing | Automated regression and workflow tests |

### Technology Stack

- **Swift and SwiftUI** — native iOS application development
- **MVVM** — separation of views and presentation logic
- **PDFKit** — PDF handling
- **Vision** — text recognition and OCR
- **Local persistence** — task storage and document metadata
- **AI-assisted retrieval** — document question-answering workflows

The exact backend and AI provider configuration may evolve as development progresses.

## Project Structure

```text
LifePilot/
├── LifePilot.xcodeproj
└── LifePilot/
    ├── App/
    ├── Core/
    ├── Domain/
    │   └── Models/
    ├── Data/
    │   └── Repositories/
    ├── Features/
    │   ├── Dashboard/
    │   ├── Documents/
    │   ├── Assistant/
    │   └── Chat/
    └── Resources/

docs/
└── images/
    ├── lifepilot-overview.png
    ├── home-dashboard.png
    ├── documents.png
    ├── pdf-assistant.png
    └── ai-chat-actions.png
```

*Illustrative structure: keep the directory names aligned with the actual repository.*

## Getting Started

### Requirements

- macOS with Xcode
- An iOS Simulator or compatible iPhone
- Any required AI service configuration for features that use a remote endpoint

### Run locally

```bash
git clone https://github.com/Ayush-Prasad4/LifePilot.git
cd LifePilot
open ios/LifePilot/LifePilot.xcodeproj
```

If the Xcode project is located elsewhere in the repository, open the actual `.xcodeproj` path instead.

Select an iOS Simulator, configure any required service settings, and build and run the app in Xcode.

## Quality & Testing

LifePilot's development includes automated testing for application logic and important user workflows.

Areas covered during development include:

- Dashboard view-model behavior
- Task creation and editing validation
- Task priority validation
- Confirmation and cancellation of pending actions
- Document and assistant workflows

Test counts and simulator coverage should be updated from the latest verified test run before publication.

## Roadmap

- [ ] Strengthen task and calendar workflows
- [ ] Improve AI assistant reliability and action validation
- [ ] Expand PDF retrieval and document intelligence
- [ ] Improve persistence and error handling
- [ ] Strengthen backend integration and security
- [ ] Polish accessibility and responsive layouts
- [ ] Complete release preparation and TestFlight validation

## Project Status

LifePilot is an actively developed portfolio project exploring native iOS engineering, AI-assisted productivity, document intelligence, and reliable user-confirmed actions.

## Author

**Ayush Prasad**

- GitHub: [@Ayush-Prasad4](https://github.com/Ayush-Prasad4)
- Portfolio: [ayushprasad.dev](https://ayushprasad.dev)

---

<p align="center">
  <strong>LifePilot</strong><br>
  Plan your work. Understand your documents. Move forward with clarity.
</p>
