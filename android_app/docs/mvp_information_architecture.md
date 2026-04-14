# MVP Mobile Information Architecture

**Android App - Cockpit Sensors**  
**Version:** 1.0  
**Date:** 2026-04-14  
**Status:** Spec Ready for Implementation

---

## Executive Summary

This document defines the **minimal viable product (MVP) information architecture** for the Android companion app that monitors a **single remote Linux host** via a read-only HTTP API. The design prioritizes mobile-first UX, clear state handling, and a simplified sensor presentation model that fits small screens without overwhelming the user.

**Key constraints enforced:**
- Single-host configuration (no multi-host switching)
- Read-only monitoring (no controls, no admin actions)
- Foreground-only operation (no background polling, no notifications)
- Tailscale/private-network security assumption (no auth flow)

---

## 1. Screen Map

### 1.1 Overview

The MVP consists of **two primary screens** with a shared state machine that manages transitions between five distinct states:

```
┌─────────────────────────────────────────────────────────────────────┐
│                        APP LIFE CYCLE                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌──────────────┐                                                  │
│   │   SETUP      │  ──────────────────────────────────────────────  │
│   │   SCREEN     │     (first-run or empty config)                  │
│   └──────┬───────┘                                                  │
│          │ Host saved / valid config                                 │
│          ▼                                                          │
│   ┌──────────────┐       ┌───────────────────────────────────────┐ │
│   │   DASHBOARD  │ ◄─────│         STATE MACHINE                 │ │
│   │   SCREEN     │ ─────►│   ┌────────┐ ┌────────┐ ┌─────────┐    │ │
│   └──────┬───────┘       │   │  Setup │ │ Loading│ │ Success │    │ │
│          │               │   └────────┘ └────────┘ └────┬────┘    │ │
│          │  ─────────────┤                              │          │ │
│          │  stale/err    │   ┌────────┐ ┌─────────┐      │          │ │
│          └──────────────►│   │  Empty │ │  Error  │      │          │ │
│                          │   └────────┘ └─────────┘      │          │ │
│                          └────────────────────────────────┘          │ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Screen Inventory

| Screen | Slug | Purpose | Entry Conditions | Exit Conditions |
|--------|------|---------|------------------|-----------------|
| **Host Setup** | `setup` | Enter/save the remote host address | First launch OR empty persisted config | Host address saved to local prefs |
| **Dashboard** | `dashboard` | View sensor readings grouped by hardware chip | Valid host config exists | User leaves app (foreground only) |

### 1.3 Navigation Model

- **No navigation bar** — single-purpose app, no back stack needed
- **No tabs or bottom navigation** — linear flow: setup → dashboard
- **Setup screen is transient** — once host is saved, user never sees it again unless config is cleared
- **Dashboard is the primary screen** — all sensor viewing happens here

---

## 2. Sensor Grouping Model (Mobile-Optimized)

### 2.1 Rationale

Desktop Cockpit displays sensors in a dense card-based layout with expand/collapse controls, hide-card actions, and a settings row. Mobile screens lack the horizontal real estate for this model. The MVP instead uses a **vertical scrollable list of grouped sensor cards** with progressive disclosure only where necessary.

### 2.2 Grouping Schema

Sensors are grouped by **hardware chip/adapter** (the `name` field from lm-sensors output, e.g., `Platform 20150000:00` or `isa-440`). Each group becomes a **SensorGroupCard** on the dashboard.

```
SensorGroupCard
├── Header (collapsible)
│   ├── Chip name (e.g., "Platform 20150000:00")
│   ├── Adapter (e.g., "PCI adapter at 0000:00:1f.0")
│   └── Expand/Collapse toggle (hidden if always-open)
├── SensorList
│   ├── SensorRow (temp1_input → CPU Package Temperature: 42.5°C)
│   ├── SensorRow (temp2_input → Core 0: 38.2°C)
│   ├── SensorRow (fan1_input → Fan 1: 2400 RPM)
│   └── ... (repeat for each sensor in the group)
```

### 2.3 Sensor Row Design

Each sensor reading is displayed as a **compact row** with:
- **Label**: Human-readable name (e.g., "CPU Package Temperature")
- **Value**: Numeric reading with unit (e.g., "42.5°C")
- **Icon**: Semantic icon based on sensor type
  - Temperature → `thermometer`
  - Fan → `cool-to-air`
  - Voltage → `power`
- **Color coding**: Optional semantic color hints
  - Temperature: blue/teal (neutral)
  - Fan: green (running)
  - Voltage: amber/yellow (caution range)

### 2.4 Group Display Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **All-open** | All groups expanded by default | Few groups (< 3) |
| **Collapsible** | Groups can be tapped to expand/collapse | Many groups (> 5) |
| **Single-expanded** | Only one group open at a time | Very long lists (> 10 groups) |

**MVP default:** All-open for simplicity; collapsible can be added in T12 polish.

### 2.5 Empty State Handling

When `sensor_groups` array is empty (status.code = "EMPTY"):
- Display **EmptyStateCard** with:
  - Icon: `dual-screen` or `analytics`
  - Title: "No sensors found"
  - Description: "The connected host doesn't report any sensor data."
  - Action: "Retry" button

---

## 3. Screen State Model

### 3.1 State Machine

The dashboard operates in one of five **mutually exclusive states**:

| State | ID | Trigger | UI Behavior | Data |
|-------|----|---------|-------------|------|
| **Setup** | `setup` | No saved host config | Show HostSetupScreen | N/A |
| **Loading** | `loading` | Polling initiated | Show loading indicator over dashboard | Previous data (if any) |
| **Success** | `success` | API returns valid sensor data | Render Dashboard with groups | Fresh sensor data |
| **Empty** | `empty` | API returns status.code = "EMPTY" | Show EmptyStateCard | Empty sensor array |
| **Error** | `error` | API returns HTTP error or timeout | Show ErrorStateCard with retry | Stale data (if available) |

### 3.2 State Transitions

```
┌─────────────────────────────────────────────────────────────────────┐
│                    STATE TRANSITION DIAGRAM                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   [Setup]                                                            │
│      │                                                               │
│      │ host saved                                                    │
│      ▼                                                               │
│   [Loading] ───────────────► [Success]                               │
│      │    \        \              │                                 │
│      │     \        \             │ poll triggers                    │
│      │      \        \            │                                  │
│      │       ▼        ▼            ▼                                  │
│      │   [Error]  [Empty]  ◄───────┘                                 │
│      │       │        │                                              │
│      │       │        └──► [Empty] (manual refresh with empty data)  │
│      │       │                                                       │
│      │       └──► [Error] (retry fails)                              │
│      │                                                               │
│      └──► [Loading] (manual refresh) ────────────────────────────────┘
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.3 State Details

#### Setup State
- **Visibility:** HostSetupScreen only
- **Data source:** Local preferences (empty)
- **Actions:**
  - Enter host address (text field)
  - Save → transitions to Loading
  - Clear → remains in Setup (for debugging)
- **Loading indicator:** N/A (user-initiated)

#### Loading State
- **Visibility:** Dashboard skeleton + progress indicator
- **Data source:** Previous successful data (if any) or blank
- **Triggers:**
  - App foreground after setup
  - Manual pull-to-refresh
  - Network recovery
- **Duration:** 0–5 seconds (configurable)
- **Actions:**
  - Pull-to-refresh (redundant but safe)
  - Go back (exits app)
- **Exit:** On first successful response → Success or Error

#### Success State
- **Visibility:** Dashboard with sensor groups
- **Data source:** Fresh API response
- **Auto-transitions:** None (user-controlled)
- **Actions:**
  - Pull-to-refresh → Loading
  - Toggle temperature units (C/F) → re-render with converted values
  - Exit app → state persists
- **Stale handling:** If refresh fails, transition to Error with stale data visible

#### Empty State
- **Visibility:** EmptyStateCard
- **Data source:** API response with status.code = "EMPTY"
- **Triggers:** Host has no lm-sensors or sensors service unavailable
- **Actions:**
  - Retry → Loading
  - Exit app
- **Distinction from Error:** Empty = host reachable, no data; Error = host unreachable or API failure

#### Error State
- **Visibility:** ErrorStateCard
- **Data source:** Stale last-known data (if available), or blank
- **Triggers:**
  - Network timeout
  - HTTP 5xx/4xx response
  - JSON parse error
- **Actions:**
  - Retry → Loading
  - Pull-to-refresh → Loading
  - Exit app
- **Stale data indicator:** Show "Last updated: HH:MM" if available

---

## 4. Unit Preference Model

### 4.1 Supported Units

| Measurement | Units | Default |
|-------------|-------|---------|
| Temperature | Celsius (°C), Fahrenheit (°F) | Celsius |
| Fan Speed | RPM (fixed) | RPM |
| Voltage | Millivolts (mV) | mV |

### 4.2 Preference Storage

- **Storage key:** `sensor_units` (SharedPreferences)
- **Structure:**
  ```json
  {
    "temperature": "C"
  }
  ```
- **Persistence:** Survives app restarts
- **UI control:** Optional unit toggle in AppBar (T12 implementation)

### 4.3 Conversion Logic

- Temperature conversion happens on the **client side** (Flutter app)
- Backend returns raw values in native units (°C for temperature, mV for voltage)
- Client applies: `°F = (°C × 9/5) + 32`
- Display formatting includes unit suffix

---

## 5. Error Handling Model

### 5.1 Error Categories

| Category | HTTP Code | User Message | Retryable |
|----------|-----------|--------------|-----------|
| **Network timeout** | N/A | "Connection timed out. Check your network." | Yes |
| **Host unreachable** | N/A | "Can't reach the host. Is it online?" | Yes |
| **HTTP error** | 4xx/5xx | "Service unavailable (error code: X)" | Yes |
| **Parse error** | N/A | "Invalid data from host." | Yes |
| **Empty data** | 200 (EMPTY status) | "No sensors found on this host." | No (manual retry) |

### 5.2 Error State Card

```
┌──────────────────────────────────────┐
│  [Icon: error_outline]               │
│                                      │
│  "Can't reach the host"              │
│  Connection timed out.               │
│  Check your network.                 │
│                                      │
│  [Last updated: 10:32 AM]            │
│                                      │
│  ┌─────────────────┐                │
│  │     Retry       │                │
│  └─────────────────┘                │
└──────────────────────────────────────┘
```

### 5.3 Stale Data Strategy

- **Show stale data** (with timestamp) before transition to Error
- **Stale indicator:** "Data may be outdated" banner
- **Stale threshold:** 30 seconds since last successful update

---

## 6. Acceptance Criteria Summary

| Criterion | Verification Method |
|-----------|---------------------|
| Single-host configuration only | No multi-host switcher in UI |
| Read-only monitoring | No control buttons, no write actions |
| Foreground-only polling | No background services declared |
| Setup → Loading → Success/Empty/Error flow | State transition tests |
| Grouped sensor cards render correctly | Widget tests with fixtures |
| Empty state for no-sensor hosts | EmptyStateCard visible on EMPTY status |
| Error state for unreachable hosts | ErrorStateCard visible on HTTP error |
| Unit toggle persists across restarts | SharedPreferences test |
| Retry action transitions to Loading | State transition test |

---

## 7. Out of Scope (Explicitly Excluded)

| Feature | Reason |
|---------|--------|
| Multi-host switching | MVP scope = single host |
| Authentication flow | Tailscale assumed for security |
| Push notifications | Background polling not supported |
| Chart/graph visualizations | MVP = raw readings only |
| Hide-card / expand-all controls | Simplified mobile layout |
| Host-admin actions (fan control, etc.) | Read-only only |
| Settings screen beyond unit toggle | Minimal MVP scope |

---

## 8. Implementation Dependencies

| Task | Dependencies |
|------|--------------|
| **T10 (Dashboard UI)** | T1 (contract), T4 (this spec), T8 (models), T9 (state controller) |
| **T11 (Error/Empty UX)** | T4 (this spec), T7 (error model), T9 (state controller) |
| **T12 (Unit preference)** | T4 (this spec), T8 (config repository) |

---

## 9. Appendix: Data Flow Diagram

```
┌──────────────┐     ┌─────────────────┐     ┌─────────────┐
│   User       │────►│   Host Setup    │────►│  SharedPreferences  │
│  enters host │     │   Screen        │     │   (host addr)   │
└──────────────┘     └─────────────────┘     └───────────────┘
                                              │
                                              ▼
┌──────────────┐     ┌─────────────────┐     ┌─────────────┐
│   UI State   │◄────│  API Controller │◄────│   API Client│
│  Controller  │     │  (polling loop) │     │ (fetch data)│
└──────────────┘     └─────────────────┘     └─────────────┘
                                              │
                                              ▼
                                     ┌─────────────────┐
                                     │   Host API      │
                                     │   (HTTP endpoint)│
                                     └─────────────────┘
                                              │
                                              ▼
                                     ┌─────────────────┐
                                     │  Sensor Parser  │
                                     │  (lm-sensors)   │
                                     └─────────────────┘

┌──────────────┐     ┌─────────────────┐
│  Dashboard   │◄────│  Sensor Models  │
│  (UI)        │     │  (Dart objects) │
└──────────────┘     └─────────────────┘
```

---

## 10. References

- **Contract:** `src/host_service/sensors_contract.json` — API response schema
- **Fixtures:** `src/host_service/fixtures/` — Success, empty, error JSON test data
- **Plan:** `.sisyphus/plans/flutter-android-migration.md` — Overall project plan
- **Existing UI:** `src/app.jsx` — Desktop Cockpit reference (for concepts only)

---

*Document end*
