# 📱 Offline-First Architecture

This app now uses an **offline-first** approach, meaning all CRUD operations happen locally first, then sync to Supabase in the background.

## 🎯 How It Works

### 1. **Local Database (Isar)**
- All data is stored locally using **Isar** (high-performance local database)
- Instant read/write operations (no network latency)
- Works completely offline

### 2. **Sync Queue**
- Every create/update/delete operation is queued for sync
- Background service processes queue when online
- Automatic retry with exponential backoff on failures

### 3. **Data Flow**

```
User Action (Create/Update/Delete)
        ↓
Save to Isar Immediately ← User sees instant feedback!
        ↓
Add to Sync Queue
        ↓
Background Sync to Supabase (when online)
        ↓
Success: Remove from queue
Failure: Retry later
```

## 📊 Data Loading Strategy

### Initial Load
1. **Load from local Isar database** (instant, even offline)
2. **Trigger background sync** from Supabase (updates in background)
3. **Merge changes** (keep local changes if pending sync)

### Date Range Filtering (for Calendar)
- **Logs**: Only last year to end of current year
- Reduces memory footprint
- Faster queries

## 🔄 Sync Behavior

### Automatic Sync Triggers
- ✅ App startup
- ✅ After any local write operation
- ✅ Internet connection restored
- ✅ Pull-to-refresh gesture
- ✅ Periodic timer (every 5 minutes)

### Manual Sync
- Pull down on the home screen to manually trigger sync and refresh data
- No visual indicators (sync is transparent to users)

## 🎨 User Experience

### Invisible Syncing
**The sync happens completely in the background** - users never see:
- ❌ No sync status indicators
- ❌ No "syncing" messages
- ❌ No loading spinners
- ❌ No network status

**Users only experience:**
- ✅ Instant operations
- ✅ Seamless functionality
- ✅ Data that "just works"

This is true offline-first UX - syncing is magical and invisible! ✨

## 🏗️ Architecture Components

### Local Models (Isar Collections)
- `LocalExercise` - Wraps ExerciseDto
- `LocalRoutineLog` - Wraps RoutineLogDto
- `LocalRoutineTemplate` - Wraps RoutineTemplateDto
- `LocalRoutinePlan` - Wraps RoutinePlanDto
- `SyncQueueItem` - Tracks pending sync operations

### Services
- **`IsarService`**: Manages local database initialization
- **`SyncService`**: Handles background synchronization
  - Processes sync queue
  - Checks connectivity
  - Retries failed operations
  - Notifies UI of sync status

### Repositories (Modified for Offline-First)
All repositories now follow this pattern:
1. **Load**: Read from local first, sync in background
2. **Save**: Write to local, queue for sync
3. **Update**: Update local, queue for sync
4. **Delete**: Delete from local, queue for sync

## 🔐 Conflict Resolution

**Strategy**: Last-Write-Wins (Simple approach)

Since the user confirmed operations never happen simultaneously from multiple devices:
- Local changes are always saved immediately
- Background sync pushes to Supabase
- If sync fails, it retries automatically
- No complex conflict resolution needed

## 🚨 Error Handling

### Sync Failures
- Automatically retry up to 10 times
- Store error message in sync queue
- User can manually trigger sync via pull-to-refresh
- App continues working offline

### Network Issues
- All operations work offline
- Sync pauses when no connection
- Resumes automatically when connection restored

## 📁 File Structure

```
lib/
├── models/local/           # Isar collection models
│   ├── local_exercise.dart
│   ├── local_routine_log.dart
│   ├── local_routine_template.dart
│   ├── local_routine_plan.dart
│   └── sync_queue_item.dart
│
├── services/
│   ├── isar_service.dart   # Local DB initialization
│   └── sync_service.dart   # Background sync logic
│
└── repositories/supabase/  # Modified for offline-first
    ├── supabase_exercise_repository.dart
    ├── supabase_routine_log_repository.dart
    ├── supabase_routine_template_repository.dart
    └── supabase_routine_plan_repository.dart
```

## 🛠️ Development Commands

### Generate Isar Code
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### View Isar Inspector (Debug Only)
```bash
# Isar Inspector is enabled by default in debug mode
# Access at: http://localhost:port (shown in console)
```

### Clear Local Database (for testing)
```dart
// In code
await IsarService.instance.writeTxn(() async {
  await IsarService.instance.clear();
});
```

## ✅ Benefits

1. **⚡ Instant Operations**: No waiting for network
2. **📴 Works Offline**: Full functionality without internet
3. **🔄 Auto-Sync**: Seamless cloud synchronization
4. **💪 Reliable**: Automatic retry on failures
5. **🎯 Simple**: No complex conflict resolution
6. **🚀 Fast**: Local database queries are instant

## 🎯 Testing Offline Mode

1. **Enable Airplane Mode** on device/simulator
2. **Create/Edit data** - should work instantly
3. **Check sync indicator** - should show pending count
4. **Disable Airplane Mode**
5. **Pull to refresh** or wait - data syncs automatically
6. **Verify in Supabase** - changes appear in cloud

---

**The app is now fully offline-first!** 🎉

