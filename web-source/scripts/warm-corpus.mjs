const TOPICS = [
  "lotnisko",
  "restauracja",
  "hotel",
  "lekarz",
  "zakupy",
  "rozmowa kwalifikacyjna",
  "biuro",
  "transport publiczny",
  "pogoda",
  "rodzina",
  "dom i mieszkanie",
  "sport",
  "technologia",
  "pieniądze i bank",
  "edukacja",
  "czas wolny",
  "telefon i internet",
  "podróż samochodem",
  "u fryzjera",
  "na poczcie",
  "small talk",
  "emocje i samopoczucie",
  "gotowanie",
  "ubrania",
  "miasto i orientacja w terenie",
];

const argument = process.argv.find((value) => value.startsWith("--url="));
const baseUrl = (argument?.slice(6) || process.env.WARM_CORPUS_URL || "").replace(/\/$/, "");
if (!baseUrl) {
  console.error("Podaj WARM_CORPUS_URL lub --url=https://adres-aplikacji.");
  process.exit(2);
}

const headers = {
  "Content-Type": "application/json",
  Origin: baseUrl,
  ...(process.env.SITES_BYPASS_BEARER_TOKEN
    ? { Authorization: `Bearer ${process.env.SITES_BYPASS_BEARER_TOKEN}` }
    : {}),
};
const totals = { generated: 0, skipped: 0, failed: 0 };

for (const topic of TOPICS) {
  try {
    const response = await fetch(`${baseUrl}/api/tutor`, {
      method: "POST",
      headers,
      body: JSON.stringify({ action: "topicList", topic }),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);
    if (data.cached) {
      totals.skipped++;
      console.log(`Pominięto: ${topic} (już w pamięci)`);
    } else {
      totals.generated++;
      console.log(`Wygenerowano: ${topic}`);
    }
  } catch (error) {
    totals.failed++;
    console.error(`Błąd: ${topic} — ${error instanceof Error ? error.message : error}`);
  }
}

console.log(
  `Podsumowanie: wygenerowano ${totals.generated}, pominięto ${totals.skipped}, błędy ${totals.failed}.`,
);
if (totals.failed) process.exitCode = 1;
