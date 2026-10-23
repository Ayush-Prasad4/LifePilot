# LifePilot — AI-Powered iOS Productivity App

LifePilot is a native iOS productivity application built with SwiftUI that brings together task management, conversational AI, and intelligent PDF document workflows in one place.

Designed around a simple principle: **organize your work, understand your documents, and take action with AI while keeping control of important changes.**

## App Showcase

<p align="center">
  <img src="docs/images/lifepilot-showcase.png" alt="LifePilot iOS application showcase featuring its implemented screens" width="100%" />
</p>

## Overview

LifePilot combines a native iOS interface with a Python-based AI backend to support everyday productivity workflows.

- **Productivity dashboard:** View task and document summaries in one place.
- **Task management:** Create, edit, complete, delete, and prioritize tasks.
- **Conversational AI:** Ask questions, continue conversations, and discuss your task context.
- **AI-assisted task actions:** Turn natural-language instructions into proposed task changes that require explicit confirmation.
- **Document intelligence:** Import PDFs, extract text using Apple frameworks, and ask questions about document content.
- **Document-grounded answers:** Generate answers from supplied document excerpts with document and page references.
- **Local persistence:** Retain planner tasks and document metadata on the device.

## Features

### 1. Home — Productivity Dashboard

The Home screen provides a central overview of productivity-related information.

- Task overview and task summaries.
- Document overview and document summaries.
- Search documents by title or category.
- Quick-action entry points for productivity workflows.
- A structured dashboard built with SwiftUI and a dedicated view model.

The dashboard currently includes repository-provided sample content for some summary cards. These previews should not be confused with live analytics derived from an external account.

### 2. Task and Calendar Management

LifePilot includes a task-planning workflow for organizing personal and study-related commitments.

**Task operations**
- Create tasks with a title and due date.
- Edit existing task details.
- Mark tasks as completed.
- Delete tasks with a confirmation step.
- Assign one of three priorities: Normal, Important, or Urgent.
- Validate task inputs before applying changes.
- Track completion state and due-date information.

**Persistence**

Planner tasks are stored locally using `UserDefaults` through `CalendarTaskStore`, under the `lifepilot.planner.tasks` key. The store uses encoded task data so saved tasks can be loaded again when the app is reopened.

Calendar and task functionality is integrated into the app's existing navigation and workflows; the planner is not a separate fifth bottom-navigation tab.

### 3. AI Chat Assistant

The Chat screen provides a conversational interface backed by the LifePilot API.

Capabilities include:

- Ask general questions and receive AI-generated responses.
- Continue conversations with recent message history.
- Ask questions about existing tasks using supplied task context.
- Discuss task titles, due dates, priorities, and completion status.
- Handle loading and server-error states.
- Request proposed task operations through natural-language instructions.

The backend receives relevant task context from the app rather than independently accessing the user's device or calendar.

### 4. AI-Assisted Task Actions

LifePilot supports a controlled workflow for turning natural-language requests into task operations.

Supported proposed actions:

| Action | Purpose |
|---|---|
| Create | Propose a new task |
| Edit | Propose changes to an existing task |
| Complete | Propose marking a task as completed |
| Delete | Propose removing an existing task |

**How the workflow works**

1. Describe the desired change in the Chat interface.
2. LifePilot sends the request and relevant task context to the backend.
3. The AI returns structured task-action proposals.
4. Review the proposed changes in the action-preview interface.
5. Confirm to apply the changes or cancel to discard them.

**Validation and safeguards**

- Empty task titles are rejected.
- Unsupported actions and invalid priorities are rejected.
- Invalid dates are rejected.
- Edit operations must contain meaningful changes.
- Operations targeting unknown task IDs are rejected.
- Task proposals are checked against the current task collection before application.
- Invalid proposal batches are rejected without saving partial changes.
- Confirmation is required before proposed operations are applied.

AI-generated proposals are not treated as completed actions. The application applies changes only through its confirmation workflow.

### 5. Documents — PDF Library

The Documents screen provides a place to manage PDF documents within LifePilot.

- Import PDF documents through the document workflow.
- Maintain document metadata in a local document library.
- Store metadata in `lifepilot-documents.json`.
- Access the PDF document assistant for supported document workflows.
- Extract text from PDF content for downstream question answering.

Document metadata and document content are separate concerns: the metadata store organizes the library, while PDF processing makes document text available to the assistant.

### 6. AI Document Assistant

The document assistant combines native PDF processing with a backend-powered question-answering workflow.

**Document processing**
- Use PDFKit to work with PDF documents.
- Use Apple's Vision framework for OCR where text extraction is required.
- Configure OCR recognition for English (`en-US`) and Italian (`it-IT`).
- Prepare extracted text and relevant excerpts for document question answering.

**Ask questions about documents**

Users can ask questions about the contents of a supported document. The app supplies document evidence to the backend, which generates an answer grounded in those excerpts.

The backend's document-answering endpoint:

- Accepts a question and document evidence.
- Includes document titles and page numbers in the supplied evidence.
- Supports limited recent conversation history.
- Instructs the model to use only supplied excerpts.
- Requires source references in the form `[Document Title, p. N]`.
- Is designed to acknowledge insufficient evidence rather than invent facts.
- Returns the generated answer and model identifier.

This is an evidence-grounded question-answering workflow, not a claim that every page of every PDF is automatically indexed or that every answer is guaranteed to be correct.

### 7. Assistant and Navigation

LifePilot uses a consistent four-tab bottom-navigation structure:

- **Home** — productivity dashboard.
- **Documents** — document library and PDF workflows.
- **Assistant** — document-focused AI assistance.
- **Chat** — conversational AI and task-action proposals.

The app is built as a native iOS application rather than a web interface embedded inside an iOS shell.

## Architecture

LifePilot separates the iOS presentation layer, application logic, local storage, and AI backend.

```text
LifePilot iOS App
│
├── SwiftUI Presentation Layer
│   ├── Home / Dashboard
│   ├── Documents
│   ├── Assistant
│   └── Chat
│
├── View Models and Domain Models
│   └── Dashboard MVVM
│
├── Local Data and Document Processing
│   ├── CalendarTaskStore
│   ├── PDFKit
│   ├── Vision OCR
│   └── Document Metadata Store
│
└── FastAPI Backend
    ├── General Chat
    ├── Document Question Answering
    ├── Structured Task-Action Proposals
    └── OpenAI Responses API
```

### Technology Stack

| Layer | Technologies |
|---|---|
| iOS application | Swift, SwiftUI |
| UI architecture | MVVM for the dashboard |
| PDF processing | PDFKit |
| Optical character recognition | Apple Vision |
| Local persistence | UserDefaults, JSON metadata |
| Networking | URLSession, JSON encoding and decoding |
| Backend | Python, FastAPI |
| Request validation | Pydantic |
| AI integration | OpenAI Python SDK and Responses API |
| Backend testing | pytest, FastAPI TestClient |

## Backend API

The backend exposes the following endpoints:

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/health` | Check API health |
| `POST` | `/v1/chat` | General conversational AI with optional task context and recent history |
| `POST` | `/v1/answer` | Answer questions using supplied document evidence |
| `POST` | `/v1/chat/actions` | Generate structured task-action proposals |

The backend validates request payloads, limits input sizes, checks required configuration, and returns structured responses.

For document question answering, the evidence must contain document titles, page numbers, and text excerpts. For task actions, the response contains proposals rather than directly mutating the iOS task store.

## Getting Started

### Prerequisites

- macOS with a compatible version of Xcode.
- An iOS Simulator or compatible iPhone.
- Python 3.11 or newer.
- An OpenAI API key for AI-powered backend functionality.

### 1. Clone the Repository

```bash
git clone https://github.com/Ayush-Prasad4/LifePilot.git
cd LifePilot
```

### 2. Open the iOS Project

Open the Xcode project or workspace provided in the repository under `ios/LifePilot`.

Select the `LifePilot` scheme, choose an available iOS Simulator or connected iPhone, and build and run the application.

### 3. Configure the Backend

Open a terminal in the repository root:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Create a `.env` file in the `backend` directory:

```dotenv
OPENAI_API_KEY=your_openai_api_key
OPENAI_MODEL=gpt-5-mini
```

Keep the `.env` file private. Never commit API keys or other secrets to GitHub.

Start the API:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Check the health endpoint:

```bash
curl http://127.0.0.1:8000/health
```

Interactive API documentation is available at:

`http://127.0.0.1:8000/docs`

### 4. Connect the iOS App to the Backend

The current chat service uses `http://127.0.0.1:8000` as its development base URL.

This address works when the API and app share the same host environment, such as a suitable local development setup. For an iOS Simulator or physical device configuration where loopback does not reach the backend, configure the base URL for the actual host or deployed API. Production deployments should use HTTPS and appropriate network-security configuration.

## Testing

LifePilot includes a Python backend test suite covering API behaviour and validation.

Areas covered include:

- Health-check responses.
- Document-answer request validation and evidence requirements.
- Conversation history handling.
- General chat responses and task context.
- Task-action proposal validation.
- Invalid or unknown task references.

The latest recorded backend test run for the task-action regression work completed with **19 passing tests**. This is a historical test result, not a claim that every iOS UI test or the entire application has been verified in the latest build.

The repository also contains dedicated iOS unit-test and UI-test targets.

## Privacy and Security Considerations

- Planner tasks and document metadata use local persistence mechanisms.
- AI requests send the relevant message, task context, or extracted document evidence to the configured backend.
- The backend requires an API key for AI-powered endpoints.
- Document-answering instructions treat excerpts as untrusted data and restrict answers to supplied evidence.
- Task operations require user confirmation in the iOS interface.
- API keys must remain in server-side environment configuration rather than the iOS application or repository.

**Deployment note:** Local persistence is not equivalent to encrypted storage, and the current development backend should not be considered production-hardened. Before deployment, configure HTTPS, production networking, secret management, access controls, and appropriate handling of sensitive document content.

## Project Structure

```text
LifePilot/
├── ios/
│   └── LifePilot/
│       ├── LifePilot/
│       │   ├── ContentView.swift
│       │   ├── Data/
│       │   └── Features/
│       │       ├── Dashboard/
│       │       ├── Chat/
│       │       └── ...
│       ├── LifePilotTests/
│       └── LifePilotUITests/
│
├── backend/
│   ├── app/
│   │   └── main.py
│   ├── tests/
│   │   └── test_main.py
│   ├── requirements.txt
│   └── .env
│
└── README.md
```

*The tree highlights the principal areas; individual files and configuration may vary by checkout.*

## Roadmap

Potential areas for continued development include:

- More comprehensive automated iOS UI and integration coverage.
- Stronger production networking and backend access controls.
- Improved persistence and recovery behaviour.
- Broader document-processing and retrieval evaluation.
- Accessibility and release-readiness improvements.

These are future development areas, not representations of already completed features.

## Author

**Ayush Prasad**

- GitHub: [Ayush-Prasad4](https://github.com/Ayush-Prasad4)
- Portfolio: [ayushprasad.dev](https://ayushprasad.dev)

## License

No license is specified here. Add a `LICENSE` file before presenting the project as open source under particular reuse terms.
