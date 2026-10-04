export function checkOrigin(req: Request): Response | null {
  const actual = req.headers.get("origin"),
    expected = new URL(req.url).origin;
  if (actual === expected) return null;
  // Do not trust forwarded headers or an arbitrary iframe parent as an origin.
  console.error("Origin rejected", {
    path: new URL(req.url).pathname,
    origin: actual?.slice(0, 300) || null,
    expected,
  });
  return Response.json(
    {
      error:
        "Nieprawidłowe źródło żądania. Otwórz aplikację pod jej własnym adresem i spróbuj ponownie.",
      code: "ORIGIN",
    },
    { status: 403, headers: { "Cache-Control": "no-store" } },
  );
}
