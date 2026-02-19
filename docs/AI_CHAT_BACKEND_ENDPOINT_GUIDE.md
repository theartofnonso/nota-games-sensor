# AI Chat Backend Endpoint Guide (Next.js App Router)

This app is now **thin client** for coach AI chat:

- Client sends: `query`, `client_id`, date range, optional `exercise_ids`
- Backend does all heavy lifting:
  - intent parsing
  - tool selection/execution
  - metric computation orchestration
  - final answer composition
- Client only renders `answer`

## Request / Response Contract

### Request

`POST /query`

```json
{
  "query": "Has bench improved in the last 8 weeks?",
  "client_id": "uuid",
  "date_from": "2026-01-01",
  "date_to": "2026-02-26",
  "exercise_ids": ["ex-bench-press-db"]
}
```

### Response (required)

```json
{
  "answer": "Your bench total volume is up 18% over the last 8 weeks..."
}
```

`answer` must always be a non-empty string when status is 200.

---

## Next.js Route (Single Endpoint)

Create this route as the only AI chat endpoint:

`app/api/query/route.ts`

Public contract remains:

`POST /query`

---

## Route Responsibilities

1. Authenticate Bearer token
2. Validate coach permissions for `client_id`
3. Parse request with strict schema
4. Run LLM as **intent router** (not math engine)
5. Execute deterministic tools (SQL/RPC + transforms)
6. Compose final natural-language answer
7. Return `{ answer }`

---

## Suggested Implementation Skeleton

```ts
import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { createClient } from "@supabase/supabase-js";

const BodySchema = z.object({
  query: z.string().min(1),
  client_id: z.string().uuid(),
  date_from: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  date_to: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  exercise_ids: z.array(z.string()).optional().default([]),
});

export async function POST(req: NextRequest) {
  try {
    const authHeader = req.headers.get("authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }
    const jwt = authHeader.slice("Bearer ".length);

    const body = BodySchema.parse(await req.json());

    // 1) Authenticated user client (RLS-aware)
    const supabaseRls = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      { global: { headers: { Authorization: `Bearer ${jwt}` } } }
    );

    const { data: authUser, error: authErr } = await supabaseRls.auth.getUser();
    if (authErr || !authUser?.user?.id) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }
    const coachId = authUser.user.id;

    // 2) Coach access check
    const { data: coachLink, error: linkErr } = await supabaseRls
      .from("coach_clients")
      .select("client_id")
      .eq("coach_id", coachId)
      .eq("client_id", body.client_id)
      .maybeSingle();
    if (linkErr || !coachLink) {
      return NextResponse.json({ error: "Forbidden" }, { status: 403 });
    }

    // 3) Resolve intent/tool call with your LLM
    //    -> must map to strict enum set (no free text SQL)
    // Example result:
    // { tool: "get_metric_series", args: { ... } }

    // 4) Execute deterministic tool(s)
    // Use service-role client for trusted backend execution:
    const supabaseAdmin = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );

    // Example:
    // const { data: series, error: rpcErr } = await supabaseAdmin.rpc("get_metric_series", {
    //   p_user_id: body.client_id,
    //   p_entity_type: "exercise",
    //   p_entity_id: "ex-bench-press-db",
    //   p_metric: "total_volume",
    //   p_start_date: body.date_from,
    //   p_end_date: body.date_to,
    //   p_group_by: "week",
    // });

    // 5) Deterministic transforms (compare/pr) in backend TS
    // 6) Compose final answer string
    const answer = "TODO: compose final answer";

    return NextResponse.json({ answer }, { status: 200 });
  } catch (err: any) {
    if (err?.name === "ZodError") {
      return NextResponse.json({ error: "Invalid request", details: err.issues }, { status: 400 });
    }
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
```

---

## Tool Policy (Backend)

Enforce strict enums server-side:

- `entity_type`: `exercise | session`
- `metric`:
  - `total_volume`
  - `total_reps`
  - `avg_load`
  - `max_load`
  - `set_count`
  - `session_count`
  - `session_total_volume`
  - `session_total_reps`
- `group_by`: `day | week | month`

If tool args are invalid, return 400 or fallback to a safe answer.

---

## Operational Notes

- Add request-id logging for traceability.
- Log tool arguments + latency + row counts.
- Set a timeout budget for LLM + RPC calls.
- Do not let LLM output numeric conclusions without tool-backed values.
- Keep all math in backend deterministic functions.

---

## App Compatibility

Current mobile app expects:

- `POST /query`
- JSON response with non-empty `answer`.

No client-side tool parsing/execution is required anymore.
