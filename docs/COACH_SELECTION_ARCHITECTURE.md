# Coach Selection — How It Works

A simple guide to how clients choose their coach in the app.

---

## Overview

When someone uses the app as a **client** and doesn’t yet have a coach, we show them a dedicated coach selection flow before they can use the rest of the app. They see a grid of coaches, tap one to view their profile (with optional video), and then choose that coach to continue.

---

## When Does Coach Selection Appear?

After logging in, the app checks whether the client already has a coach:

- If they **do** → they go straight into the main app.
- If they **don’t** → we show the coach selection flow.
- If they’ve already completed selection (e.g. in a previous session) but there’s a delay in confirming their coach, we also let them through to the main app.

This check happens only for client accounts, not for coaches.

---

## The Coach Selection Flow

**1. Coach grid**

The client sees a full-screen list of available coaches in a two-column grid. Each coach is shown with their photo and name. Tapping a coach opens their profile.

**2. Coach profile (bottom sheet)**

Tapping a coach opens a panel that shows:

- **Background:** Optional video about the coach, or a solid color if no video is set.
- **Content:** The coach’s photo, name, a short description, and a “Choose Coach” button.
- **Layout:** All content is anchored near the bottom of the panel for clear reading.

**3. Choosing a coach**

When the client taps “Choose Coach,” we link them to that coach and mark the selection as complete. The profile panel closes and they enter the main app.

If something goes wrong, they see a message asking them to try again.

---

## What Information We Use

- **Coaches:** Name, photo, optional video, and description — used to display the grid and profile.
- **Client–coach links:** Which coach is assigned to which client.
- **Selection status:** Whether the client has finished the selection flow (used to decide whether to show it again).

---

## User Journey (Plain Language)

1. Client logs in.
2. App checks if they already have a coach.
3. If not, the coach selection screen appears.
4. Client browses the grid and taps a coach.
5. The coach’s profile opens with photo, name, description, and optional video.
6. Client taps “Choose Coach.”
7. The app saves their choice and lets them into the main app.

---

## Summary

The coach selection flow is a short, required step for clients who don’t have a coach. They browse coaches, view a profile, and choose one. Once selected, they can use the rest of the app normally.
