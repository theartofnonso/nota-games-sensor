# RLS Ownership-Based Policies

RLS policies are refactored to be **ownership-based** rather than role-based. Coaches and clients can create and manage data according to ownership; coach-led subscription and UX are gated in the app.

## Policy Summary

| Table | Read | Write (insert/update/delete) |
|-------|------|-----------------------------|
| **routine_plans** | `owner = auth.uid()` OR `clientId = auth.uid()` | Same |
| **routine_templates** | `owner = auth.uid()` OR `clientId = auth.uid()` | Same |
| **nutrition_templates** | `owner = auth.uid()` OR `client_id = auth.uid()` | Same |
| **nutrition_logs** | `user_id = auth.uid()` OR coach in `coach_clients` for that user | `user_id = auth.uid()` only |

## Who Can Do What

- **Coach**: Creates plans/templates for clients (`owner` = coach, `clientId`/`client_id` = client). Reads client logs via `coach_clients`.
- **Client**: Reads plans/templates assigned to them (`clientId` = their id). Can create and manage their own plans/templates where the app allows; writes use `owner`/`clientId` consistent with their user id.

## Note

Schema and RLS are managed in the backend database. This doc describes the ownership-based policy logic.
