# FitForge

FitForge is an iOS SwiftUI prototype for all-in-one health, diet, strength training, running, HYROX, and marathon tracking.

## Current Scope

- Daily calorie intake, expenditure, and balance dashboard
- Weekly, monthly, and annual theoretical weight change vs actual weight change
- Meal logging with an AI-analysis service seam for text and photo-based estimates
- PFC macro estimates
- Strength progression tracking with weight, reps, sets, and estimated 1RM
- Progression reminders for increasing weight
- Running, HYROX, and marathon session records
- HealthKit authorization and read hooks for body mass, steps, calories, and workouts
- 30-second check-ins for loose daily tracking
- Local JSON persistence in the app documents directory
- Japanese-first localization-ready copy structure
- Japanese exercise catalog with aliases and English labels
- User-configurable day boundary based on wake time
- First-run onboarding for goal, wake time, weight target, weekly workout frequency, and meal tracking style
- SwiftData model foundation while keeping JSON persistence for MVP compatibility
- Editable AI meal estimates before saving
- Manual HealthKit daily sync for steps, active energy, basal energy, and latest body mass
- SwiftData hydration back into the in-memory app store
- Remote meal AI endpoint support with local fallback estimation
- 7-day and 30-day HealthKit history sync actions
- Goal-aware dashboard and loose meal quick logging
- MVP sub-agent roles for health, nutrition, training, endurance, user experience, development, marketing, privacy, sports medicine, and analytics

## Local Setup

Open `FitForge.xcodeproj` in Xcode, select an iOS simulator or device, and run the `FitForge` scheme.

HealthKit works best on a real iPhone with Health data available. The current app contains sample data so the UI is useful before connecting live services.

## Next Build Steps

- Replace `MealAIService` with a real API-backed nutrition analyzer
- Add photo picker and camera capture for meal images
- Persist logs with SwiftData
- Add Apple Health background sync
- Add Garmin, Strava, and Apple Watch workout import paths
- Add goal-plan generation that suggests calorie targets, training frequency, and cardio volume
