# To-Do List

A Flutter task manager for organizing daily work with reminders, alarms, and voice-powered task creation.

## Features

- Create, edit, delete, and complete tasks.
- Add descriptions, notes, categories, priorities, due dates, and alarms.
- Search tasks and filter them by completion status, priority, category, overdue state, or due date.
- Sort tasks by custom order, priority, or due date.
- Schedule local reminders and full-screen alarms for upcoming tasks.
- Receive overdue task notifications.
- Create tasks with native speech recognition and Gemini AI parsing.
- Fall back to offline task parsing when the AI service is unavailable.
- Share task details with other apps.
- Persist tasks and theme preferences locally on the device.
- Switch between light and dark themes.
- Get completion feedback with vibration and animated celebrations.

## Getting Started

1. Install Flutter and run `flutter pub get`.
2. Copy `.env.example` to `.env`.
3. Add your Gemini API key to `.env`:

   ```env
   GEMINI_API_KEY=your_api_key_here
   ```

4. Run the app with `flutter run`.
