import {reportFile} from "@/lib/report-store";
import { checkOrigin } from "@/lib/request-origin";
import { headers } from "next/headers";
import { database } from "@/db/store";
import { seed } from "@/lib/learning";
import { z } from "zod";
export const dynamic = "force-dynamic";
import { stateSchema } from "@/lib/state-schema";

async function owner() {
  return (await headers()).get("oai-authenticated-user-id");
}
const error = () =>
  Response.json(
    {
      error:
        "Nie udało się połączyć z kontem. Twoje zmiany pozostają na ekranie.",
    },
    { status: 503 },
  );
export async function GET() {
  const id = await owner();
  if (!id)
    return Response.json(
      { error: "Zaloguj się, aby synchronizować dane." },
      { status: 401 },
    );
  try {
    const db = database();
    await db
      .prepare(
        "INSERT OR IGNORE INTO learners (owner,content,revision,updated_at) VALUES (?,?,0,?)",
      )
      .bind(id, JSON.stringify(seed()), Date.now())
      .run();
    const row = await db
      .prepare("SELECT content,revision FROM learners WHERE owner=?")
      .bind(id)
      .first<{ content: string; revision: number }>();
    return Response.json(
      { state: JSON.parse(row!.content), revision: row!.revision },
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch (e) {
    console.error("Load failed", e);
    return error();
  }
}
export async function PUT(req: Request) {
  const id = await owner();
  if (!id) return Response.json({ error: "Zaloguj się." }, { status: 401 });
  const blocked = checkOrigin(req);
  if (blocked) return blocked;
  try {
    const raw = await req.text();
    if (raw.length > 8_000_000)
      return Response.json(
        { error: "Zbyt duży zbiór danych" },
        { status: 413 },
      );
    const result = z
      .object({ state: stateSchema, revision: z.number().int().min(0) })
      .safeParse(JSON.parse(raw));
    if (!result.success)
      return Response.json(
        { error: "Niepoprawny format danych." },
        { status: 400 },
      );
    const { state, revision } = result.data;
    const update = await database()
      .prepare(
        "UPDATE learners SET content=?,revision=revision+1,updated_at=? WHERE owner=? AND revision=?",
      )
      .bind(JSON.stringify(state), Date.now(), id, revision)
      .run();
    if (!update.meta.changes) {
      const current = await database()
        .prepare("SELECT content,revision FROM learners WHERE owner=?")
        .bind(id)
        .first<{ content: string; revision: number }>();
      return Response.json(
        {
          error:
            "Dane zmieniły się na innym urządzeniu. Fluent spróbuje je automatycznie scalić.",
          state: current ? JSON.parse(current.content) : null,
          revision: current?.revision,
        },
        { status: 409 },
      );
    }
    return Response.json({ revision: revision + 1 });
  } catch (e) {
    console.error("Save failed", e);
    return error();
  }
}
export async function DELETE(req: Request) {
  const id = await owner();
  if (!id) return Response.json({ error: "Zaloguj się." }, { status: 401 });
  const blocked = checkOrigin(req);
  if (blocked) return blocked;
  try {
    const db = database();
    const reports=await db.prepare("SELECT id FROM exercise_reports WHERE owner=?").bind(id).all<{id:string}>();
    for(const report of reports.results)await reportFile(report.id,null);
    await db.batch([
      db.prepare("DELETE FROM exercise_reports WHERE owner=?").bind(id),
      db.prepare("DELETE FROM report_corrections WHERE owner=?").bind(id),
      db.prepare("DELETE FROM learners WHERE owner=?").bind(id),
      db.prepare("DELETE FROM tutor_usage WHERE owner=?").bind(id),
      db.prepare("DELETE FROM gemini_connections WHERE owner=?").bind(id),
    ]);
    return Response.json({ ok: true });
  } catch (e) {
    console.error("Delete failed", e);
    return error();
  }
}
