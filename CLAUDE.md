# AI Apples to Apples

## Project Overview
Multiplayer iOS party game (2–4 players). A random image ("green card") is shown. 
Players write prompts to generate AI images that match/complement it. 
The group votes on the best one. First to 3 points wins.

## Tech Stack
- SwiftUI, targeting iOS 17+
- Firebase Anonymous Auth (name entry, no account creation)
- Cloud Firestore for real-time game sessions
- Firebase Storage for generated image uploads
- Lorem Picsum API for green card images
- OpenAI Images API (gpt-image-1) for player-generated images

## Architecture Decisions
- MVVM pattern with @Observable classes (iOS 17)
- Firebase listeners via AsyncStream for real-time state sync across devices
- Game state machine: lobby → prompting → generating → voting → results → (repeat or finished)
- Generating phase is skipped if all images are ready when prompting ends
- OpenAI calls made directly via URLSession (API key in APIKeys.swift, gitignored)
- Host device drives state transitions and auto-advance logic
- Submissions/votes stored as dictionaries keyed by playerId in Round document

## Key Rules
- Players CANNOT vote for their own image
- Max 4 players per session
- First to 3 points wins (goes directly to game over, no extra "Next Round" step)
- Tied votes split points — each tied player gets a point
- Host can end the game at any time; any player can leave at any time
- Game auto-ends if fewer than 2 players remain
- Green card = random Lorem Picsum image, new each round
- Sessions visible to join only while in lobby state
