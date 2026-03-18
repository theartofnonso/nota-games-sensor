# RLS Ownership-Based Policies

RLS policies are refactored to be **ownership-based** rather than role-based. Both coaches and self-coaching clients can create and manage data; access is gated in the app.

## Policy Summary

| Table | Read | Write (insert/update/delete) |
|-------|------|-----------------------------|
| **routine_plans** | `owner = auth.uid()` OR `clientId = auth.uid()` | Same |
| **routine_templates** | `owner = auth.uid()` OR `clientId = auth.uid()` | Same |
| **nutrition_templates** | `owner = auth.uid()` OR `client_id = auth.uid()` | Same |
| **nutrition_logs** | `user_id = auth.uid()` OR coach in `coach_clients` for that user | `user_id = auth.uid()` only |

## Who Can Do What

- **Coach**: Creates plans/templates for clients (`owner` = coach, `clientId`/`client_id` = client). Reads client logs via `coach_clients`.
- **Pro client**: Reads plans/templates assigned to them (`clientId` = their id). Cannot create; app gates this.
- **Self-coaching client**: Creates plans/templates for themselves (`owner` = `clientId` = their id). Same write access as coach for their own data.

## Note

Schema and RLS are managed in the backend database. This doc describes the ownership-based policy logic.
