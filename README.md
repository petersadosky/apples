# AI Apples to Apples

A multiplayer iOS party game where players compete to generate the best AI image. Each round, a random photo is shown as the "green card." Players write prompts to generate AI images that match or complement it, then everyone votes on the best one. First to 3 points wins.

2–4 players. No accounts required.

## How It Works

1. **Create or join** a game from the lobby
2. **Write a prompt** — everyone sees the same green card image and writes a prompt to generate an AI image that matches it
3. **Vote** — tap the image you think is the best match (you can't vote for your own)
4. **Score** — the winner gets a point, ties split points. First to 3 wins!

## Tech Stack

- **SwiftUI** with MVVM architecture and `@Observable` (iOS 17+)
- **Firebase Anonymous Auth** — players just enter a name, no sign-up
- **Cloud Firestore** — real-time game state sync across devices via `AsyncStream` listeners
- **Firebase Storage** — persistent storage for generated images
- **OpenAI gpt-image-1** — AI image generation with retry logic
- **Lorem Picsum** — random green card images each round

## Project Structure

```
apples/
├── Models/          # GameSession, GameState, Player, Round, Submission, Vote
├── Views/           # SwiftUI views for each game phase
├── ViewModels/      # GameCoordinator — state machine and game logic
├── Services/        # Firebase auth, Firestore, image generation
└── applesApp.swift  # App entry point
CloudFunctions/
├── firestore.rules  # Auth-based Firestore security rules
├── storage.rules    # Auth-based Storage security rules
└── functions/       # Cloud Functions
```

## Game Flow

```
Lobby → Prompting → Generating → Voting → Results → (next round or game over)
```

The host drives state transitions. The generating phase is automatically skipped if all images are ready when prompting ends.

## Setup

### Prerequisites

- Xcode 15+ with iOS 17 SDK
- A Firebase project with **Anonymous Auth**, **Cloud Firestore**, and **Cloud Storage** enabled
- An OpenAI API key with access to `gpt-image-1`

### Configuration

1. **Clone the repo**

2. **Firebase** — Add your `GoogleService-Info.plist` to `apples/` (not tracked by git)

3. **OpenAI API key** — Create `apples/Services/APIKeys.swift` (not tracked by git):
   ```swift
   enum APIKeys {
       static let openAI = "sk-your-key-here"
   }
   ```

4. **Firebase project ID** — Create `CloudFunctions/.firebaserc`:
   ```json
   {
     "projects": {
       "default": "your-firebase-project-id"
     }
   }
   ```

5. **Deploy security rules**:
   ```bash
   cd CloudFunctions
   firebase deploy --only firestore:rules,storage --project your-firebase-project-id
   ```

6. **Build and run** in Xcode

## Game Rules

- 2–4 players per session
- Players cannot vote for their own image
- Tied votes split points — each tied player gets a point
- First to 3 points wins
- Host can end the game at any time; any player can leave at any time
- Game auto-ends if fewer than 2 players remain
