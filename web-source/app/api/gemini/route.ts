import { headers } from "next/headers";
import {
  geminiGenerate,
  geminiError,
  validKey,
  listGeminiModels,
  withModelFallback,
  compatibleGeminiModels,
} from "@/lib/gemini";
import {
  connectionStatus,
  saveConnection,
  disconnect,
  refreshModels,
} from "@/lib/gemini-account";
import { checkOrigin } from "@/lib/request-origin";
import { quotaOwner, quotaStatus } from "@/lib/tutor-server";
export const dynamic = "force-dynamic";
const json = (data: unknown, status = 200) =>
  Response.json(data, { status, headers: { "Cache-Control": "no-store" } });
async function owner() {
  return (await headers()).get("oai-authenticated-user-id");
}
export async function GET(req?: Request) {
  const id = await owner();
  try {
    return json({
      ...(await connectionStatus(id)),
      limit: await quotaStatus(await quotaOwner(id, req)),
    });
  } catch (error) {
    return geminiError(error);
  }
}
export async function POST(req: Request) {
  const id = await owner();
  if (!id) return json({ error: "Zaloguj się, aby połączyć Gemini." }, 401);
  const blocked = checkOrigin(req);
  if (blocked) return blocked;
  let key: string;
  try {
    const raw = await req.text();
    if (raw.length > 2000)
      return json({ error: "Zbyt długie dane połączenia." }, 413);
    const data = JSON.parse(raw);
    if (!validKey(data.key))
      return json(
        {
          error:
            "Wklej sam klucz API z Google AI Studio, bez spacji, opisu ani cudzysłowów.",
          code: "LOCAL_KEY_FORMAT",
        },
        400,
      );
    key = data.key.trim();
  } catch {
    return json(
      { error: "Niepoprawny format danych połączenia.", code: "LOCAL_REQUEST" },
      400,
    );
  }
  try {
    const available = await listGeminiModels(key);
    const models = compatibleGeminiModels(available, "text");
    const result = await withModelFallback(models, async (model) => {
      const d = await geminiGenerate(
        key,
        "Connection check. Return ok=true.",
        {},
        {
          type: "object",
          properties: { ok: { type: "boolean" } },
          required: ["ok"],
          additionalProperties: false,
        },
        model,
      );
      if (d.ok !== true) throw new Error("INCOMPLETE");
      return d;
    });
    const speechModel = compatibleGeminiModels(available, "speech")[0] || null;
    await saveConnection(id, key, result.model, speechModel);
    return json({
      connected: true,
      model: result.model,
      speechModel,
      checkedAt: Date.now(),
      limit: await quotaStatus(id),
    });
  } catch (error) {
    return geminiError(error);
  }
}
export async function PATCH(req: Request) {
  const id = await owner();
  if (!id) return json({ error: "Zaloguj się." }, 401);
  const blocked = checkOrigin(req);
  if (blocked) return blocked;
  try {
    return json({
      ...(await refreshModels(id)),
      checkedAt: Date.now(),
      limit: await quotaStatus(id),
    });
  } catch (error) {
    return geminiError(error);
  }
}
export async function DELETE(req: Request) {
  const id = await owner();
  if (!id) return json({ error: "Zaloguj się." }, 401);
  const blocked = checkOrigin(req);
  if (blocked) return blocked;
  try {
    await disconnect(id);
    return json({
      ...(await connectionStatus(id)),
      limit: await quotaStatus(id),
    });
  } catch (error) {
    return geminiError(error);
  }
}
